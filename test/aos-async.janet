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
  # ⚠ read-json 是 keyword 鍵，handle 的 args 是字串鍵，只能逐值比
  (assert (= "async" ((e2 :args) :who)) "登記表那筆記著父傳的引數（daemon 靠它重建 AOS_ARG_*）"))

# ── ③ 登記表那筆的形狀要合 registry.schema.json ────────────────────────
# ⚠ 裁決 S-08-66（2026-09-05）把 result／args 升成頂層正式欄，`ext.result`／`ext.args` 作廢。
#   這裡不能接著②讀——原型 aosp/registry.py 的 _canonicalize 會先幫忙 pop 掉 ext 裡那兩個，
#   斷言就變成恆真。所以另開沙盒、假裝 daemon 是自己，讓登記表只有綁定寫過。
(def sb3 (U/sandbox "async-shape"))
(def child3 (aos/init-land! (string sb3 "/child") {:source U/echo-arg-source}))
(def reg3-path (string sb3 "/home/.aos/registry.json"))
(aos/ensure-dir (string sb3 "/home/.aos"))
(aos/write-json reg3-path {:format_version 1 :daemon_pid (os/getpid)
                           :daemon_pid_start :null :entries []})
(def h3 (aos/call-async child3 {:who "shape"}))
(def e3 (find |(= (child3 :root) ($ :path)) ((aos/read-json reg3-path {}) :entries)))
(assert (= (h3 :result) (e3 :result)) "落點寫在頂層 result")
(assert (= "shape" ((e3 :args) :who)) "引數寫在頂層 args")
(assert (nil? (get (e3 :ext) :result)) "ext.result 作廢，綁定禁止再寫")
(assert (nil? (get (e3 :ext) :args)) "ext.args 作廢，綁定禁止再寫")

(print "aos 脫節呼叫測試通過 ✓")
