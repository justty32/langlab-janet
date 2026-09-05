# aos：**一個檔案＝一筆指令** —— exec-file 拿得到 stdout／stderr／結束碼，投遞協定照規矩走。

(import ../modules/aos :as aos)
(import ./aos-util :as U)

(if-not (U/proto-ready?)
  (do (print "aos 檔案當指令測試跳過（找不到 proto/aos.py）✓") (os/exit 0)))

(def sb (U/sandbox "inst"))

# ── ① 檔案當指令：stdout、stderr、結束碼三樣都拿得回來 ────────────────
(def r (aos/exec-file "/bin/sh" "-c" "echo out-$GREET; echo bad >&2; exit 7"
                      {:env {"GREET" "hi"}}))
(assert (= 7 (r :code)) "結束碼原樣回傳（傳輸層，不是做成沒做成）")
(assert (string/find "out-hi" (r :out)) "stdout 讀得回來，env 也傳得進去")
(assert (string/find "bad" (r :err)) "stderr 讀得回來")
(assert (nil? (r :spawn-error)) "跑起來了就沒有 spawn_error")

# 同一塊地叫第二次也要行（收件匣是每格取一次，不會互相卡）
(assert (string/find "second" ((aos/exec-file "/bin/echo" "second") :out)) "叫得動第二次")

# ── ② 執行結果檔真的落在 .aos/ticks/<N>/results/ 底下 ─────────────────
(assert (aos/exists? (r :result)) "執行結果檔在")
(def res (aos/read-json (r :result)))
(assert (= (r :id) (res :id)) "結果檔的 id 跟投遞物同一個")
(assert (= false (res :timed_out)) "沒逾時")

# ── ③ 找不到那支程式＝沒跑起來，spawn_error 要有東西（兩個頻道分開）───
(def miss (aos/exec-file "/definitely/not/here-xyz"))
(assert (nil? (miss :code)) "沒跑起來就沒有結束碼")
(assert (miss :spawn-error) "沒跑起來要寫 spawn_error")

# ── ④ 投遞協定：id 一定是 32 hex，不是就當場擋下來 ────────────────────
(def land (aos/init-land! (string sb "/box") {:noop true}))
(def [ok e] (protect (aos/deliver! land {:id "short" :kind "mail" :subject "x"})))
(assert (not ok) "id 不是 32 hex 該被擋")
(assert (string/find "S-07-35" (string e)) "錯誤要指到 spec 那一條")
(def [ok-upper e-upper]
  (protect (aos/deliver! land {:id "ABCDEF0123456789ABCDEF0123456789" :kind "mail"})))
(assert (not ok-upper) "id 雖然夠長，但大寫 hex 也要擋")
(assert (string/find "S-07-35" (string e-upper)) "大寫 id 的錯誤也要指到 spec")

# 一封信只會被搬到 .aos/mail/，不會被執行（S-07-45）
(def p (aos/mail! land "hello" "隨便寫的內文"))
(assert (string/has-suffix? ".json" p) "投遞完是 <id>.json")
(assert (aos/exists? p) "投遞物真的在收件匣裡")
(aos/exec-once (land :root))
(assert (not (aos/exists? p)) "走一格之後信被取走了")
(assert (= 1 (length (os/dir (string (land :aos) "/mail")))) "信被搬到 .aos/mail/")

(print "aos 檔案當指令測試通過 ✓")
