# aos：**脫節呼叫** —— 沒 daemon 就照 P-01 直接失敗；有 daemon 就 handle → await 拿結果。
# ⚠ 這支會起一支真的 daemon，但家（AOS_HOME）指在暫存目錄，收工一定停掉。

(import ../modules/aos :as aos)
(import ./aos-util :as U)

(if-not (U/proto-ready?)
  (do (print "aos 脫節呼叫測試跳過（找不到 proto/aos.py）✓") (os/exit 0)))

(def sb (U/sandbox "async"))
(def child (aos/init-land! (string sb "/child") {:source U/echo-arg-source}))

# ── ① 沒有 daemon：當場失敗，而且呼叫方看得見（狀態檔寫 no_daemon）──────
(assert (not (aos/daemon-alive?)) "沙盒裡本來就沒有 daemon")
(def [ok e] (protect (aos/call-async child {:who "nobody"})))
(assert (not ok) "沒 daemon 的脫節呼叫要當場失敗（裁決 P-01）")
(assert (string/find "no_daemon" (string e)) "錯誤要講是 no_daemon")
(assert (string/find "aos/daemon :start" (string e)) "錯誤要指出下一步")

# ── ② 有 daemon：handle → :pending → await → :done ────────────────────
(aos/daemon :start)
(defer (aos/daemon :stop)
  (assert (aos/daemon-alive?) "daemon 起來了")
  (def h (aos/call-async child {:who "async"}))
  (assert (aos/handle? h) "call-async 回一個 handle")
  (assert (= (child :root) (h :child)) "handle 記著呼叫的是誰")
  (assert (= "hi async" (aos/await h 20000)) "await 拿得到結果")
  (assert (= :done (aos/status h)) "拿到之後 status 是 :done")

  # 登記表那筆真的帶著結果落點（`aos run` 靠它重建 AOS_RESULT）
  (def reg (aos/read-json (string sb "/home/.aos/registry.json") {}))
  (def e2 (find |(= (child :root) ($ :path)) (reg :entries)))
  (assert e2 "子地登記在登記表上")
  (assert (= (h :result) (e2 :result)) "登記表那筆記著父指定的落點")
  (assert (= (h :result) ((e2 :ext) :result)) "schema 定的 ext.result 也要有落點"))

(print "aos 脫節呼叫測試通過 ✓")
