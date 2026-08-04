# CLI 的**主流程** —— 從解析結果走到「印出答案或死掉」。也是 CLI 這層的門面。
#
# 從 main.janet 拆出來的理由只有一個：**讓 CLI 邏輯可以離線測**。
# main.janet 現在只剩「把 (dyn :args) 交給 run」這一句；能純函式化的都放在旁邊三支：
#
#   cli-flags.janet  usage 文字與旗標定義、parse-args
#   cli-args.janet   命令列字串 → Janet 值（parse-kv／param-table／resolve-endpoint…）
#   cli-list.janet   --list 那一大段輸出（回字串，不 print）
#
# 這三支都由本檔 re-export，所以 (import ./cli) 之後照舊拿得到 cli/parse-kv、
# cli/list-text、cli/flags…，只有 run 本身住在這裡。
#
# ★ 輸出約定：stdout 只放乾淨的回答文字（方便往下 pipe），
#   所有診斷／trace／錯誤一律走 stderr，失敗退出碼非 0。

(import ./cli-flags :prefix "" :export true)
(import ./cli-args  :prefix "" :export true)
(import ./cli-list  :prefix "" :export true)
(import ./endpoints :as ep)
(import ./chat :as conv)
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

(defn fmt-args
  "把工具參數印成 k=v，字串直接印本文。
  ⚠ 不用 %q —— Janet 的 quoted 印法會把非 ASCII 逃逸成 \\xE5\\x8F\\xB0，中文全看不懂。"
  [args]
  (string/join
    (seq [[k v] :pairs args]
      (string/format "%s=%s" k (if (bytes? v) (string v) (string/format "%q" v))))
    " "))

(defn- ask-once
  "一般問答那條：打一次，把答案文字挖出來。"
  [cfg messages params]
  (def r (conv/chat cfg messages :params params))
  (or (conv/reply-text r)
      (error (string "回應裡取不出答案文字：" (string/format "%q" r)))))

(defn- ask-with-tools
  "tool loop 那條：trace 走 stderr，才不會弄髒 stdout 的答案。"
  [cfg messages params max-rounds]
  (def out (tools/with-tools cfg messages tools/demo-tools tools/demo-handlers
                             :max-rounds max-rounds
                             :params params
                             :trace (fn [n a r]
                                      (eprintf "→ 工具 %s(%s)\n← %s" n (fmt-args a) r))))
  (when (out :exhausted)
    (error (string/format "打滿 %d 輪模型還在要工具，中止。" max-rounds)))
  (or (out :text) ""))

(defn run
  ``CLI 的主流程。argv 的第 0 個是執行檔自己。會 os/exit，所以測試請叫上面那些純函式。``
  [argv]
  (def res (parse-args argv))
  # argparse 解析失敗（或 --help）時回傳 nil，usage 已自動印出
  (unless res (os/exit 1))

  # --endpoints 要在任何「查名字」的動作之前先載進來
  (let [[ok e] (protect (load-config-files! res))]
    (unless ok (die "%s" e)))

  (when (res "list") (print (list-text)) (os/exit 0))

  (def positional (or (res :default) @[]))
  (def name (get positional 0))
  (unless name
    (die "缺 endpoint 名字。用法：llm-http <%s> [prompt...]（--help 看說明）"
         (string/join (ep/endpoint-names) "|")))

  (def [cfg-ok cfg] (protect (resolve-endpoint res name)))
  (unless cfg-ok (die "%s" cfg))
  (unless cfg
    (die (string "沒有這個 endpoint：%s\n可用的有：%s\n"
                 "（想打沒註冊過的伺服器，請同時給 --model 與 --url／--base；"
                 "或用 --endpoints <檔案> 載入你自己的設定）")
         name (string/join (ep/endpoint-names) "、")))

  (def images (res "image"))
  (when (and images (not (empty? images)) (false? (cfg :vision?)))
    (eprintf "⚠ endpoint %s 目前指到的模型不吃圖，送過去可能報錯、也可能被靜默無視。" name))

  (def prompt
    (let [words (slice positional 1)]
      (if (empty? words) (read-stdin-prompt) (string/join words " "))))
  (when (empty? prompt)
    (die "prompt 是空的，沒東西可問。"))

  (def [params-ok params] (protect (request-params res)))
  (unless params-ok (die "%s" params))

  # 有 system 就先放一則，接著是 user（帶圖時 content 自動變 parts 陣列）
  (def messages @[])
  (when-let [s (res "system")] (array/push messages @{:role "system" :content s}))
  (array/push messages (media/user-message prompt images))

  (def max-rounds (if-let [r (res "rounds")] (scan-number r) 8))
  (def [ok answer]
    (protect
      (if (res "tools")
        (ask-with-tools cfg messages params max-rounds)
        (ask-once cfg messages params))))

  (unless ok (die "呼叫 %s 失敗：%s" name answer))

  # ★ 只有這一行進 stdout
  (print answer))
