#!/usr/bin/env janet
# CLI 進入點 —— 只負責解參數、決定往哪印、決定退出碼。核心邏輯在同目錄那四個檔。
#
# 跑法：
#   janet modules/llm-http/main.janet local 你好           # 直接跑
#   jpm build && ./build/llm-http local 你好                # 編成單一執行檔
#   echo "翻成英文：貓" | ./build/llm-http deepseek         # 沒給 prompt 就讀 stdin
#   ./build/llm-http --list                                 # 列出四個 endpoint
#   ./build/llm-http --tools local "現在幾點？用工具查"      # 跑多輪 tool loop
#   ./build/llm-http --image /tmp/a.png local "這是什麼？"   # 丟圖進去（可重複給多張）
#   ./build/llm-http --base http://127.0.0.1:4111 local 嗨   # 換一台 proxy
#
# ★ 輸出約定：stdout 只放乾淨的回答文字（方便往下 pipe），
#   所有診斷／trace／錯誤一律走 stderr，失敗退出碼非 0。

(import spork/argparse :as ap)
(import ./endpoints :as ep)
(import ./client)
(import ./media)
(import ./tools)

(defn- die
  [fmt & args]
  (eprint (string/format fmt ;args))
  (os/exit 1))

(defn- read-stdin-prompt
  ``沒給位置參數當 prompt 時，把 stdin 整段讀到 EOF 當 prompt。

  ⚠ stdin 既不是 tty、又沒人餵東西時這裡會**永久卡住**——這是 unix filter 的正常語意，
  不是 bug。在 CI／`bash -c` 裡測請一律帶 `< /dev/null`。``
  []
  (when (os/isatty stdin)
    (eprint "（讀 stdin 中，輸入完按 Ctrl-D 送 EOF）"))
  (string/trim (string (or (file/read stdin :all) ""))))

(defn- fmt-args
  "把工具參數印成 k=v，字串直接印本文。
  ⚠ 不用 %q —— Janet 的 quoted 印法會把非 ASCII 逃逸成 \\xE5\\x8F\\xB0，中文全看不懂。"
  [args]
  (string/join
    (seq [[k v] :pairs args]
      (string/format "%s=%s" k (if (bytes? v) (string v) (string/format "%q" v))))
    " "))

(defn- print-list []
  (each n (ep/endpoint-names)
    (def spec (get ep/specs n))
    (printf "%-11s model=%-11s %s" n (spec :model)
            (if (spec :vision?) "吃圖" "純文字"))
    (printf "            %s" (spec :note))
    (printf "            proxy 端需要的環境變數：%s%s"
            (or (spec :env) "（不需要）")
            (if (ep/env-ready? n) "" "  ⚠ 本機未設")))
  (printf "\nproxy base：%s（LITELLM_BASE 可覆寫）" (ep/base-url)))

(defn main
  [& args]
  (def res
    (ap/argparse
      (string "llm-http —— 純 Janet 打 litellm proxy 的 OpenAI 相容端點\n"
              "  用法：llm-http [旗標] <local|deepseek|claude|openrouter> [prompt 文字...]\n"
              "  沒給 prompt 文字就讀 stdin 到 EOF 當 prompt；\n"
              "  ⚠ stdin 非 tty 又沒人餵會一直卡著等（unix filter 正常語意），測試請加 < /dev/null。\n"
              "  stdout 只有回答本文，診斷與錯誤都走 stderr。")
      "system" {:kind :option :short "s" :help "system 訊息（可省略）。"}
      "model"  {:kind :option :short "m" :help "覆寫送給 proxy 的 model 名稱。"}
      "base"   {:kind :option :short "b" :help "proxy base URL，預設 http://127.0.0.1:4000。"}
      "image"  {:kind :accumulate :short "i"
                :help "圖檔路徑或 http(s)/data URL，可重複給。⚠ 要挑吃圖的 endpoint。"}
      "tools"  {:kind :flag :short "t" :help "啟用內建示範工具（now／get_weather），跑多輪 tool loop。"}
      "rounds" {:kind :option :help "tool loop 最多打幾輪，預設 8。"}
      "list"   {:kind :flag :short "l" :help "列出內建 endpoint 就結束。"}
      :default {:kind :accumulate
                :help "第一個是 endpoint 名字，其餘串成 prompt。"}))

  # argparse 解析失敗（或 --help）時回傳 nil，usage 已自動印出
  (unless res (os/exit 1))

  (when (res "list") (print-list) (os/exit 0))

  (def positional (or (res :default) @[]))
  (def name (get positional 0))
  (unless name
    (die "缺 endpoint 名字。用法：llm-http <%s> [prompt...]（--help 看說明）"
         (string/join (ep/endpoint-names) "|")))

  (def overrides @{})
  (when-let [m (res "model")] (put overrides :model m))
  (when-let [b (res "base")]  (put overrides :base b))
  (def cfg (ep/endpoint name overrides))
  (unless cfg
    (die "沒有這個 endpoint：%s（可用：%s）" name (string/join (ep/endpoint-names) "、")))

  (def images (res "image"))
  (when (and images (not (empty? images)) (not (cfg :vision?)))
    (eprintf "⚠ endpoint %s 目前指到的模型不吃圖，送過去可能報錯、也可能被靜默無視。" name))

  (def prompt
    (let [words (slice positional 1)]
      (if (empty? words) (read-stdin-prompt) (string/join words " "))))
  (when (empty? prompt)
    (die "prompt 是空的，沒東西可問。"))

  # 有 system 就先放一則，接著是 user（帶圖時 content 自動變 parts 陣列）
  (def messages @[])
  (when-let [s (res "system")] (array/push messages @{:role "system" :content s}))
  (array/push messages (media/user-message prompt images))

  (def [ok answer]
    (protect
      (if (res "tools")
        # ── tool loop ──────────────────────────────────────────────
        (let [max-rounds (if-let [r (res "rounds")] (scan-number r) 8)
              out (tools/with-tools cfg messages tools/demo-tools tools/demo-handlers
                                    :max-rounds max-rounds
                                    # trace 走 stderr，才不會弄髒 stdout 的答案
                                    :trace (fn [n a r]
                                             (eprintf "→ 工具 %s(%s)\n← %s" n (fmt-args a) r)))]
          (when (out :exhausted)
            (error (string/format "打滿 %d 輪模型還在要工具，中止。" max-rounds)))
          (or (out :text) ""))
        # ── 一般問答 ───────────────────────────────────────────────
        (let [r (client/chat cfg messages)]
          (or (client/reply-text r)
              (error (string "回應裡取不出答案文字：" (string/format "%q" r))))))))

  (unless ok (die "呼叫 %s 失敗：%s" name answer))

  # ★ 只有這一行進 stdout
  (print answer))
