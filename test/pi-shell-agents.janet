# pi-shell：agent registry ＋ 指令組法 ＋ agent 設定檔。
#
# 指令組法（agent-argv）是純函式，不 spawn；真的要跑的地方一律拿 cat 當無害替身，
# **不會呼叫 pi／claude 或任何付費 API**。
#
# ⚠ 一開頭就 reset-agents!：使用者本機可能有 ~/.config/pi-shell/agents.janet
#   會被 import 時自動載入，測試要先打回「只剩內建兩筆」才有確定性。

(import ../modules/pi-shell/init :as agent)
(import ./util :as u)

(agent/reset-agents!)

# ── 內建兩筆 ────────────────────────────────────────────────────────
(assert (deep= @["claude" "pi"] (agent/agent-names)) "reset 之後只剩內建兩個 agent")
(assert (agent/builtin-agent? "pi"))
(assert (= :builtin (agent/agent-source "claude")))
(assert (= "pi" agent/pi-cmd))
(assert (= "claude" agent/claude-cmd))
(assert (= "claude-haiku-4-5-20251001" agent/default-claude-model))
(assert (find |(= "claude-sonnet-5" $) agent/claude-models))

# ── 指令組法（不真的執行）──────────────────────────────────────────
(assert (deep= @["pi" "-p" "--no-tools" "回 ok"]
                (agent/agent-argv "pi" ["--no-tools" "回 ok"]))
        "pi 墊 -p，其餘原樣透傳")
(assert (deep= @["claude" "-p" "回 ok"] (agent/agent-argv "claude" ["回 ok"])))
(assert (deep= @["claude" "-p" "--model" "claude-haiku-4-5-20251001" "回 ok"]
                (agent/agent-argv "claude" ["回 ok"] "claude-haiku-4-5-20251001"))
        "model 墊在 -p 後面、args 前面")
# 不在 registry 的名字＝直接當執行檔名（維持 run-agent 原本的語意）
(assert (deep= @["my-cli" "-p" "x"] (agent/agent-argv "my-cli" ["x"])))
# 也可以直接給一張 table，不必註冊
(assert (deep= @["foo" "--ask" "-m" "big" "x"]
                (agent/agent-argv {:cmd "foo" :prompt-flag "--ask"
                                   :model-flag "-m" :default-model "big"}
                                  ["x"]))
        "inline agent：自訂非互動旗標與 model 旗標")

# ── 自訂 agent：註冊 ────────────────────────────────────────────────
(agent/define-agent "qwen-cli" {:cmd "qwen" :model-flag "-m" :note "本機 qwen"})
(assert (deep= @["qwen" "-p" "嗨"] (agent/agent-argv "qwen-cli" ["嗨"])))
(assert (not (agent/builtin-agent? "qwen-cli")))
(assert (= :runtime (agent/agent-source "qwen-cli")))
(assert (agent/undefine-agent! "qwen-cli"))

# :prompt-flag false ＝ 完全不墊旗標（有些 CLI 的 prompt 就是位置參數）
(agent/define-agent "raw" {:cmd "cat" :prompt-flag false})
(assert (deep= @["cat"] (agent/agent-argv "raw" [])))
# 真的跑一次（拿 cat 當無害替身，不碰任何 agent CLI）
(def r5 (agent/run-agent "raw" [] "透過 registry 跑起來\n"))
(assert (= "透過 registry 跑起來\n" (r5 :out)) "自訂 agent 真的 spawn 得起來")
(assert (agent/agent-available? "raw") "cat 在 PATH 上")
(agent/undefine-agent! "raw")

# 設定不合法要給看得懂的中文錯誤
(assert (string/find "缺 :cmd" (u/err-of |(agent/define-agent "x" {:note "沒指令"}))))
(assert (string/find "不認得的欄位" (u/err-of |(agent/define-agent "x" {:cmd "y" :cmdd "z"}))))
(assert (string/find "必須是一張 table" (u/err-of |(agent/define-agent "x" "cat"))))

# ── 自訂 agent：設定檔 ──────────────────────────────────────────────
(def tmp-dir (string (or (os/getenv "TMPDIR") "/tmp") "/janet-lab-pi-shell-test"))
(os/mkdir tmp-dir)
(def good-path (string tmp-dir "/agents.janet"))
(spit good-path `{"cat-agent" {:cmd "cat" :prompt-flag false :note "拿 cat 當假 agent"}}`)
(assert (deep= @["cat-agent"] (agent/load-agents! good-path)))
(assert (= good-path (agent/agent-source "cat-agent")) "來源記的是檔案路徑")
(assert (= "從設定檔載進來的\n"
           ((agent/run-agent "cat-agent" [] "從設定檔載進來的\n") :out))
        "設定檔裡的 agent 真的跑得起來")

(def broken-path (string tmp-dir "/broken.janet"))
(spit broken-path `{"a" {:cmd "x"}`)                      # 少一個右括號
(assert (string/find "格式有誤" (u/err-of |(agent/load-agents! broken-path))))
(assert (string/find "找不到 agent 設定檔"
                     (u/err-of |(agent/load-agents! (string tmp-dir "/沒這個.janet")))))

(os/setenv "PI_SHELL_AGENTS" good-path)
(assert (= good-path (first (agent/config-candidates))) "環境變數排在探測順序第一")
(os/setenv "PI_SHELL_AGENTS" nil)

(os/rm good-path)
(os/rm broken-path)
(os/rmdir tmp-dir)
(agent/reset-agents!)

(print "pi-shell agent registry 測試通過 ✓")
