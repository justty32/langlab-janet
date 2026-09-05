# aos：**一塊地＝一支程式** —— 同步呼叫拿到結果、失敗拿到狀態檔、(aos/fn) 糖。
# 全部在暫存沙盒裡跑，不碰使用者的 ~，也不起 daemon。

(import ../modules/aos :as aos)
(import ./aos-util :as U)

(if-not (U/proto-ready?)
  (do (print "aos 同步呼叫測試跳過（找不到 proto/aos.py，設 AOS_PROTO 再跑）✓")
      (os/exit 0)))

(def sb (U/sandbox "call"))

# ── ① 認一塊地：沒有 .aos/ 要報看得懂、指得出下一步的錯 ──────────────
(def [ok e] (protect (aos/land (string sb "/not-a-land"))))
(assert (not ok) "不是資料夾就該失敗")
(assert (string/find "aos/init-land!" (string e)) "錯誤訊息要指出下一步")

# ── ② 同步呼叫：args 變 AOS_ARG_*，結果落在父指定的落點 ─────────────
(def child (aos/init-land! (string sb "/child") {:source U/echo-arg-source}))
(assert (aos/land? child) "init-land! 回的是 land 物件")
(assert (= "hi janet" (aos/call child {:who "janet"})) "同步呼叫拿得到結果")
(assert (= "hi 42" (aos/call child {:who 42})) "args 的值要以字串寫進記錄與環境變數")

# 呼叫記錄真的落在呼叫方那塊地的 .aos/calls/
(def calls (os/dir ((aos/workspace) :calls)))
(assert (not (empty? calls)) "呼叫記錄要寫在呼叫方的 .aos/calls/")
(def rec (aos/read-json (string ((aos/workspace) :calls) "/" (first calls))))
(assert (= "sync" (rec :mode)) "呼叫記錄記著 mode")
(assert (= (child :root) (rec :child)) "呼叫記錄記著子地的真實路徑")

# ── ③ (aos/fn 地)：資料夾當函式，而且叫得動第二次 ────────────────────
(def greet (aos/fn child))
(assert (= "hi sugar" (greet {:who "sugar"})) "(aos/fn 地) 就是呼叫")
(assert (= "hi third" (greet {:who "third"})) "同一塊地叫得動第二次（rearm!）")

# ── ④ 三態：子地寫了狀態檔＝壞了，錯誤要帶 reason 與狀態檔路徑 ───────
(def bad (aos/init-land! (string sb "/bad") {:source U/status-source}))
(def [ok2 e2] (protect (aos/call bad {})))
(assert (not ok2) "狀態檔在＝這次呼叫壞了")
(assert (string/find "boom" (string e2)) "錯誤要帶子地寫的 reason")
(assert (string/find ".status.json" (string e2)) "錯誤要指出狀態檔在哪")

# ── ⑤ 三態：閒著了但兩個檔都沒有＝no_result（S-07-77）─────────────────
(def quiet (aos/init-land! (string sb "/quiet") {:source U/fail-source}))
(def quiet-result (string ((aos/workspace) :root) "/out/quiet.out"))
(def [ok3 e3] (protect (aos/call quiet {} {:result quiet-result})))
(assert (not ok3) "什麼都沒寫也算失敗")
(assert (string/find "no_result" (string e3)) "要講清楚是 no_result")
(assert (aos/exists? (aos/status-path quiet-result)) "no_result 要依 S-07-77 寫狀態檔")

(def quiet2 (aos/init-land! (string sb "/quiet2") {:source U/fail-source}))
(def quiet2-result (string ((aos/workspace) :root) "/out/quiet2.out"))
(assert (nil? (aos/call quiet2 {} {:on-missing :nil :result quiet2-result}))
        ":on-missing :nil 就回 nil")
(assert (= :failed (first (aos/triple quiet2-result)))
        ":on-missing :nil 也不能省掉 no_result 狀態檔")

(def malformed (string ((aos/workspace) :root) "/out/malformed.out"))
(aos/atomic-write (aos/status-path malformed) "{not json")
(assert (= :failed (first (aos/triple malformed))) "解不開的狀態檔也必須算壞了（S-07-69）")

# ── ⑥ 落點的規矩：保留後綴與 .aos/ 裡面都不准 ───────────────────────
(each bad-path [".status.json" "sub.usage.json"]
  (def [okx ex] (protect (aos/call child {:who "x"} {:result bad-path})))
  (assert (not okx) (string bad-path " 該被擋下來"))
  (assert (string/find "S-07-59" (string ex)) "要指到 spec 那一條"))

(def [ok-out e-out] (protect (aos/call child {:who "x"} {:result (string sb "/escape.out")})))
(assert (not ok-out) "結果落點不能跑出呼叫方那塊地")
(assert (string/find "S-07-57" (string e-out)) "越界錯誤要指到 spec")

(print "aos 同步呼叫測試通過 ✓")
