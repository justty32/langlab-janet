# agent：CLI 那一層的純函式——旗標解析、endpoint 組法、工具組法、tracer、agent-opts。不 os/exit、不打網路。

(import ../modules/agent/cli :as cli)
(import ../modules/agent/init :as ag)
(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

# ── 旗標 ────────────────────────────────────────────────────────────
(def res (cli/parse-args @["agent" "-e" "local" "-r" "modules" "--allow-write" "-v" "幫我" "看看"]))
(assert res "命令列解得開")
(assert (= "local" (res "endpoint")))
(assert (= "modules" (res "root")))
(assert (res "allow-write"))
(assert (res "verbose"))
(assert (deep= @["幫我" "看看"] (res :default)) "問題本文是位置參數")
(def dflt (cli/parse-args @["agent"]))
(assert (= "local" (dflt "endpoint")) "預設 endpoint 是 local")
(assert (= "." (dflt "root")) "預設 root 是目前目錄")
(assert (nil? (dflt "allow-write")) "寫入預設關")
(assert (nil? (dflt "allow-shell")) "shell 預設關")

# ── endpoint-of：名字＋覆寫 ─────────────────────────────────────────
(def cfg (cli/endpoint-of (cli/parse-args @["agent" "-m" "qwen" "-b" "http://127.0.0.1:4111"])))
(assert (= "qwen" (cfg :model)) "--model 覆寫")
(assert (= "http://127.0.0.1:4111/v1/chat/completions" (cfg :url)) "--base 組出 url")
(def cfg-url (cli/endpoint-of (cli/parse-args @["agent" "-u" "http://127.0.0.1:1234/v1/chat/completions"])))
(assert (= "http://127.0.0.1:1234/v1/chat/completions" (cfg-url :url)) "--url 直接指定")
(assert (nil? (cli/endpoint-of (cli/parse-args @["agent" "-e" "沒這個"]))) "找不到名字回 nil")

# ── build-tools：旗標決定有哪些工具 ─────────────────────────────────
(defn names [argv] (ag/tool-names (cli/build-tools (cli/parse-args argv))))
(assert (deep= @["calc" "http-get" "list-dir" "now" "read-file" "search-files"] (names @["agent" "-r" "modules"]))
        "預設：只讀、有 http-get、沒 shell")
(assert (index-of "write-file" (names @["agent" "-r" "modules" "--allow-write"])))
(assert (index-of "run-command" (names @["agent" "-r" "modules" "--allow-shell"])))
(assert (not (index-of "http-get" (names @["agent" "-r" "modules" "--no-http"]))))
(def shell-res (cli/parse-args @["agent" "-r" "modules" "--allow-shell" "--shell-allow" "ls" "--shell-allow" "git status"]))
(def rc (get (ag/as-table (cli/build-tools shell-res)) "run-command"))
(assert (string/find "只允許以這些開頭：ls、git status" (rc :description)) "白名單進了工具說明")
(assert (string/has-prefix? "工具執行失敗：拒絕" (ag/call-tool [rc] "run-command" @{:command "rm -rf /"})))
(assert (string/find "不存在" (u/err-of |(cli/build-tools (cli/parse-args @["agent" "-r" "/沒這個目錄"]))))
        "root 不存在要講清楚")

# ── tracer-of ───────────────────────────────────────────────────────
(assert (nil? (cli/tracer-of (cli/parse-args @["agent"]))) "沒 -v 沒 --trace-file 就安靜")
(assert (function? (cli/tracer-of (cli/parse-args @["agent" "-v"]))))
(def tf (string (or (os/getenv "TMPDIR") "/tmp") "/janet-agent-trace-" (os/getpid) ".log"))
(def tracer (cli/tracer-of (cli/parse-args @["agent" "--trace-file" tf])))
(tracer @{:kind :tool :step 1 :name "calc" :args @{:expression "1+1"} :result "2" :ms 0.5})
(tracer @{:kind :done :steps 1 :stopped-by :done :usage @{:prompt-tokens 3 :completion-tokens 4}})
(def logged (string (slurp tf)))
(assert (string/find "→ calc(expression=1+1)" logged) (string "trace 檔內容：" logged))
(assert (string/find "[完成] 1 步，停在 done，tokens=3+4" logged))
(os/rm tf)

# ── agent-opts：整包組起來（含 --resume）────────────────────────────
(def opts (cli/agent-opts (cli/parse-args @["agent" "-r" "modules" "-s" "S" "--max-steps" "4" "--temperature" "0.2" "問"])))
(assert (= "S" (opts :system)))
(assert (= 4 (opts :max-steps)))
(assert (= 0.2 (opts :temperature)))
(assert (nil? (opts :memory)) "沒 --resume 就沒有既有記憶")
(assert (= "local" (get-in opts [:endpoint :name])))
(assert (string/find "沒有這個 endpoint" (u/err-of |(cli/agent-opts (cli/parse-args @["agent" "-e" "沒這個"])))))

(def mf (string (or (os/getenv "TMPDIR") "/tmp") "/janet-agent-resume-" (os/getpid) ".json"))
(def m (ag/make-memory :system "舊"))
(ag/append! m @{:role "user" :content "以前"})
(ag/save! m mf)
(def opts2 (cli/agent-opts (cli/parse-args @["agent" "-r" "modules" "--resume" mf])))
(assert (= 2 (length (ag/messages (opts2 :memory)))) "--resume 讀回既有記憶")
(def ag2 (ag/make-agent opts2))
(assert (= "舊" (ag/system-of (ag2 :memory))) "make-agent 吃得下 agent-opts 的結果")
(os/rm mf)

(print "agent CLI 測試通過 ✓")
