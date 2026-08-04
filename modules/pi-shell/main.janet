#!/usr/bin/env janet
# CLI 進入點 —— 薄薄一層：參數原樣轉發給 `pi -p`（或 `claude -p`／你自己註冊的 agent），
# 自己的 stdin 整段餵進去，子行程的 stdout 原樣印出來，退出碼原樣回傳。
#
# 哪些旗標本殼要吃掉在 ./cli.janet（拆出去是為了能離線測），
# agent 的形狀知識在 ./agents.janet，子行程管線在 ./proc.janet。
#
# 跑法：
#   janet modules/pi-shell/main.janet --no-tools "回一個字 ok"        # 直接跑
#   jpm build && ./build/pi-shell --no-tools "回一個字 ok"             # 編成單一執行檔
#   cat notes.md | ./build/pi-shell --no-tools "用一句話總結"          # stdin 一起餵進去
#   ./build/pi-shell --claude --disallowedTools Bash Edit Write "回 ok"  # 改跑 claude CLI
#   ./build/pi-shell --list-agents                                     # 看 registry 裡有哪些
#   ./build/pi-shell --agent qwen-cli "回 ok"                          # 跑自己註冊的 agent
#
# ★ 除了 --claude 與（只認第一個位置的）--agent／--agent-file／--list-agents 之外
#   刻意不做參數解析（連 --help 都讓給子行程）：這支是透傳殼，
#   `pi`／`claude` 原本能吃什麼旗標就繼續能吃什麼。
#
# ⚠ pi 與 claude 預設都帶 bash/edit/write，會**真的動你的檔案**。
#   要縮限請自己加 --no-tools（pi）或 --disallowedTools（claude）。
# ⚠ claude 那條每次呼叫都是真金白銀（見 ../../FINDINGS.md 第四節）。

(import ./init :as agent)
(import ./cli)

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

(defn main
  [& args]
  # args 的第 0 個是執行檔自己，其餘原樣往後送
  (def [ok opts] (protect (cli/take-flags (slice args 1))))
  (unless ok (eprint opts) (os/exit 2))

  # --agent-file 要在任何「查名字」的動作之前先載進來
  (each f (opts :agent-files)
    (def [ok2 e] (protect (agent/load-agents! f)))
    (unless ok2 (eprint e) (os/exit 2)))

  (when (opts :list?)
    (print (cli/list-text))
    (os/exit 0))

  (def name (opts :agent))
  (unless (get agent/agent-specs name)
    (eprintf "沒有這個 agent：%s（可用：%s；--list-agents 看詳細）"
             name (string/join (agent/agent-names) "、"))
    (os/exit 2))

  (def stdin-str (slurp-stdin))
  (def [ok3 r] (protect (agent/run-agent name (opts :args) stdin-str)))
  (unless ok3
    (eprintf "起不了子行程：%s（%s 在 PATH 上嗎？）"
             r ((agent/agent-spec name) :cmd))
    (os/exit 127))
  (prin (r :out))
  (flush)
  (os/exit (r :code)))
