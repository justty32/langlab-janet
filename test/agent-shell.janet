# agent：run-command（白名單／逾時／截斷）與 http-get（https 擋下、http 走假伺服器）。
# 跑的都是 sh／echo／sleep 這種一定在的指令；HTTP 只打同行程的假伺服器。

(import spork/http)
(import ../modules/agent/init :as ag)
(import ./util :as u)

# ── 白名單比對 ──────────────────────────────────────────────────────
(assert (ag/allowed? nil "rm -rf /") "沒給白名單 = 不限")
(assert (ag/allowed? ["ls" "git status"] "ls"))
(assert (ag/allowed? ["ls" "git status"] "ls -la"))
(assert (ag/allowed? ["ls" "git status"] "git status --short"))
(assert (not (ag/allowed? ["ls"] "lsblk")) "前綴後面要是空白或結尾")
(assert (not (ag/allowed? ["git status"] "git push")))
(assert (not (ag/allowed? ["ls"] "ls; rm -rf /")) "分號不會被 shell 解釋，但白名單也不放行")
(assert (deep= @["ls" "-la"] (ag/split-command "  ls   -la ")))

# ── run-command：正常、非 0、逾時 ────────────────────────────────────
(def r (ag/run-command ["sh" "-c" "echo out; echo err >&2; exit 3"]))
(assert (= 3 (r :code)))
(assert (= "out\n" (r :out)))
(assert (= "err\n" (r :err)))
(assert (not (r :timed-out?)))

(def t0 (os/clock))
(def slow (ag/run-command ["sleep" "5"] :timeout 0.3))
(assert (slow :timed-out?) "逾時要標出來")
(assert (nil? (slow :code)) "被 kill 的沒有退出碼")
(assert (< (- (os/clock) t0) 3) "真的有在 0.3 秒左右被砍掉，不是等 sleep 跑完")
(assert (string/find "起不了指令" (u/err-of |(ag/run-command ["這支執行檔不存在-xyz"]))))

# 大量輸出不會卡死（pipe buffer 塞滿時要邊跑邊讀）
(def big (ag/run-command ["sh" "-c" "yes | head -c 200000"]))
(assert (= 200000 (length (big :out))))

# ── 包成工具：預設沒有、白名單、截斷、格式 ───────────────────────────
(assert (not (index-of "run-command" (ag/tool-names (ag/default-tools)))) "預設工具組沒有 run-command")
(def sh (ag/shell-tool :allow ["echo" "seq"] :timeout 1 :max-output 60))
(assert (= "run-command" (sh :name)))
(assert (string/find "只允許以這些開頭：echo、seq" (sh :description)) "白名單寫進說明，模型看得到")

(def ok-out (ag/call-tool [sh] "run-command" @{:command "echo hi there"}))
(assert (= "exit code: 0\nstdout:\nhi there\n" ok-out) (string "格式：" ok-out))
(assert (string/has-prefix? "工具執行失敗：拒絕：「ls」不在允許的指令清單裡（echo、seq）"
                            (ag/call-tool [sh] "run-command" @{:command "ls"})))
(assert (string/find "指令是空的" (ag/call-tool [sh] "run-command" @{:command "   "})))
(def clipped (ag/call-tool [sh] "run-command" @{:command "seq 1 1000"}))
(assert (string/find "輸出已截斷，共 " clipped) (string "截斷：" clipped))
(assert (< (length clipped) 200) "截到 max-output 附近，不是整段 1000 行")
(def timed (ag/call-tool [(ag/shell-tool :timeout 0.2)] "run-command" @{:command "sleep 2"}))
(assert (string/has-prefix? "⚠ 逾時被中止\nexit code: （無）" timed) (string "逾時格式：" timed))

# ── http-get ─────────────────────────────────────────────────────────
(def e-https (u/err-of |(ag/http-get "https://example.com/")))
(assert (= ag/https-hint e-https) "https 在送出去之前就擋下，訊息就是 https-hint")
(assert (= ag/https-hint (u/err-of |(ag/http-get "ftp://x"))) "不是 http:// 開頭的一律擋")
(assert (= (string "工具執行失敗：" ag/https-hint)
           (ag/call-tool [(ag/http-get-tool)] "http-get" @{:url "https://example.com"}))
        "包成工具後是錯誤字串回給模型")

(def port 45723)
(def srv (http/server
           (http/router {"/hello" (fn [_] {:status 200 :headers {"content-type" "text/plain"} :body "你好 world"})
                         "/big"   (fn [_] {:status 200 :body (string/repeat "x" 100)})})
           "127.0.0.1" port))
(def base (string "http://127.0.0.1:" port))
(def got (ag/http-get (string base "/hello")))
(assert (= 200 (got :status)))
(assert (= "你好 world" (got :body)) "body 是字串不是 buffer")
(assert (= 404 ((ag/http-get (string base "/nope")) :status)) "404 也是正常回傳，不丟例外")
(assert (= "HTTP 200\n\n你好 world" (ag/call-tool [(ag/http-get-tool)] "http-get" @{:url (string base "/hello")})))
(def clipped-http (ag/call-tool [(ag/http-get-tool :max-bytes 10)] "http-get" @{:url (string base "/big")}))
(assert (= (string "HTTP 200\n\n" (string/repeat "x" 10) "\n…（已截斷，共 100 bytes）") clipped-http))
(:close srv)
(assert (string/find "抓不到" (u/err-of |(ag/http-get "http://127.0.0.1:45799/"))) "連不上要說清楚")

(print "agent run-command／http-get 測試通過 ✓")
