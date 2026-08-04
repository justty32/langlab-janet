# pi-shell：CLI 的**旗標消化規則** —— 純函式，不 spawn 任何東西。
#
# 這一層要回答的問題只有一個：哪些旗標是**本殼自己的**、哪些要原樣透傳給子行程。
# 最後順便探測 pi／claude 在不在（只問版本，不請它們做事）。

(import ../modules/pi-shell/init :as agent)
(import ../modules/pi-shell/cli :as cli)
(import ./util :as u)

(agent/reset-agents!)

# 預設跑 pi，什麼都不吃掉
(def t1 (cli/take-flags @["--no-tools" "回 ok"]))
(assert (= "pi" (t1 :agent)))
(assert (deep= @["--no-tools" "回 ok"] (t1 :args)))

# --claude 在**任何位置**都吃得掉（沿用原本的行為）
(def t2 (cli/take-flags @["--model" "m" "--claude" "回 ok"]))
(assert (= "claude" (t2 :agent)))
(assert (deep= @["--model" "m" "回 ok"] (t2 :args)) "--claude 被吃掉，其餘原樣")

# 只吃第一個 --claude，第二個原樣往下送
(def t3 (cli/take-flags @["--claude" "--claude" "x"]))
(assert (deep= @["--claude" "x"] (t3 :args)))

# --agent／--agent-file／--list-agents 只認**第一個參數位置**
(def t4 (cli/take-flags @["--agent" "qwen-cli" "--agent-file" "/tmp/a.janet" "回 ok"]))
(assert (= "qwen-cli" (t4 :agent)))
(assert (deep= @["/tmp/a.janet"] (t4 :agent-files)))
(assert (deep= @["回 ok"] (t4 :args)))

# 放在後面就**不算**本殼的旗標，原樣透傳給子行程
# （claude 自己就有 --agents，本殼不能在任何位置都攔截）
(def t5 (cli/take-flags @["回 ok" "--agent" "別攔我"]))
(assert (= "pi" (t5 :agent)))
(assert (deep= @["回 ok" "--agent" "別攔我"] (t5 :args)))

(def t6 (cli/take-flags @["--list-agents"]))
(assert (t6 :list?))
(assert (string/find "--agent 後面要接" (u/err-of |(cli/take-flags @["--agent"]))))

# --list-agents 的輸出要看得出內建與自訂
(agent/define-agent "我的" {:cmd "mine"})
(def listed (cli/list-text))
(assert (string/find "內建" listed))
(assert (string/find "我的" listed))
(assert (string/find "define-agent 註冊的" listed))
(agent/reset-agents!)

# ── 探測（只問版本，不請它做事）────────────────────────────────────
(printf "pi 可用？%q   claude 可用？%q" (agent/pi-available?) (agent/claude-available?))

(print "pi-shell CLI 測試通過 ✓")
