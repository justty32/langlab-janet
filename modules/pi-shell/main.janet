#!/usr/bin/env janet
# CLI 進入點 —— 薄薄一層：參數原樣轉發給 `pi -p`（或 `claude -p`），
# 自己的 stdin 整段餵進去，子行程的 stdout 原樣印出來，退出碼原樣回傳。
# 核心邏輯在 ./init.janet 與 ./proc.janet。
#
# 跑法：
#   janet modules/pi-shell/main.janet --no-tools "回一個字 ok"        # 直接跑
#   jpm build && ./build/pi-shell --no-tools "回一個字 ok"             # 編成單一執行檔
#   cat notes.md | ./build/pi-shell --no-tools "用一句話總結"          # stdin 一起餵進去
#   ./build/pi-shell --claude --disallowedTools Bash,Edit,Write "回 ok"  # 改跑 claude CLI
#
# ★ 除了自己的 --claude 之外刻意不做參數解析（連 --help 都讓給子行程）：
#   這支是透傳殼，`pi`／`claude` 原本能吃什麼旗標就繼續能吃什麼
#   （--model／--no-tools／--allowedTools／--output-format／@file …）。
#
# ⚠ pi 與 claude 預設都帶 bash/edit/write，會**真的動你的檔案**。
#   要縮限請自己加 --no-tools（pi）或 --disallowedTools（claude）。
# ⚠ claude 那條每次呼叫都是真金白銀（見 ../../FINDINGS.md 第四節）。

(import ./init :as agent)

(defn- slurp-stdin
  ``把自己的 stdin 整段讀進來當子行程的輸入。

  stdin 是互動終端時直接回 nil —— 否則 `./pi-shell "問題"` 在終端裡打會卡在等輸入。
  非 tty 就讀到 EOF；⚠ 非 tty 又沒人餵東西會**永久卡住**，這是 unix filter 的正常語意，
  不是 bug。在 CI／`bash -c` 這類環境測請一律帶 `< /dev/null`。``
  []
  (if (os/isatty stdin)
    nil
    (let [s (file/read stdin :all)]
      (if (or (nil? s) (empty? s)) nil (string s)))))

(defn- take-claude-flag
  ``把 --claude（唯一由本殼消化掉的旗標）從參數裡挑出來。
  回 [剩下的參數 用不用 claude]。其餘旗標一律原樣留著往下送。``
  [args]
  (def rest @[])
  (var claude? false)
  (each a args
    (if (and (not claude?) (= a "--claude"))
      (set claude? true)
      (array/push rest a)))
  [rest claude?])

(defn main
  [& args]
  # args 的第 0 個是執行檔自己，其餘原樣往後送
  (def [forwarded claude?] (take-claude-flag (slice args 1)))
  (def stdin-str (slurp-stdin))
  (def [ok r] (protect (if claude?
                         (agent/run-claude forwarded stdin-str)
                         (agent/run-pi forwarded stdin-str))))
  (unless ok
    (eprintf "起不了子行程：%s（%s 在 PATH 上嗎？）"
             r (if claude? agent/claude-cmd agent/pi-cmd))
    (os/exit 127))
  (prin (r :out))
  (flush)
  (os/exit (r :code)))
