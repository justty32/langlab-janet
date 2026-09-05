# 脫節呼叫（spec 07 S-07-06、S-07-27、S-07-28）：子地自己有鐘，父不等它。
# 真正去起 `aos run <子> --register` 的是 daemon（裁決 G-01／P-01）——所以這裡只做兩件事：
#   ① 往 $AOS_HOME/.aos/registry.json 登記一筆 pending（帶 result／parent／args）
#   ② daemon 不在就照 P-01 當場失敗：代子寫狀態檔 no_daemon，讓呼叫方看得見
#
# ⚠ `aos daemon add` 登不了 result／parent／args（只有時鐘），而 `aos run` 正是靠登記表
#   那三欄重建子地的 AOS_RESULT／AOS_CALLER／AOS_ARG_*。所以登記表只能自己寫。findings 第 5 條。

(import spork/path)
(import ./fsx)
(import ./land :as L)
(import ./call :as C)

(defn- home-dir [] (or (os/getenv "AOS_HOME") (os/getenv "HOME")))
(defn- registry-file [] (path/join (home-dir) ".aos" "registry.json"))

(defn daemon-alive?
  "登記表的 daemon_pid 還活著嗎（S-07-28 就看這個）。"
  []
  (def reg (fsx/read-json (registry-file) {}))
  (fsx/pid-alive? (reg :daemon_pid)))

(defn- register! [child result caller args]
  (def f (registry-file))
  (fsx/ensure-dir (path/dirname f))
  (fsx/with-lock (path/join (path/dirname f) "registry.lock")
    (def reg (fsx/read-json f @{:format_version 1 :daemon_pid nil :entries @[]}))
    (def now (fsx/now-iso))
    (def e @{:path child :pid :null :pid_start :null :land_id :null :state "pending"
             :clock {:kind "until" :until "idle"} :budget :null :runner "run"
             # 原型還讀頂層 result／args；正式形狀同時放進 ext。
             :result result :args args :parent caller :ext {:result result :args args}
             :registered_at now :updated_at now})
    (def kept (filter |(not= (get $ :path) child) (or (reg :entries) [])))
    (put reg :entries [;kept e])
    (fsx/write-json f reg)
    e))

(defn call-async
  ``脫節呼叫：登記子地的鐘就回一個 handle，不等它跑完。daemon 一定要在。

  (def h (aos/call-async "sub/" {:who "janet"}))
  (aos/status h)      # :pending / :done / :failed
  (aos/await h 5000)  # 等到好或壞（毫秒上限）``
  [l &opt args opts]
  (default args {}) (default opts {})
  (def clean-args (fsx/string-args args))
  (def child (L/land l))
  (def caller (L/workspace))
  (def id (fsx/new-id))
  (def result (C/alloc-result caller opts id))
  (C/call-record! caller child :async result clean-args id)
  (unless (= false (opts :rearm)) (C/rearm! child))
  (def handle @{:kind :aos/handle :id id :child (child :root)
                :caller (caller :root) :result result :args clean-args :opts opts})
  (unless (daemon-alive?)
    (def msg (string "no_daemon：沒有 daemon 在看管（" (registry-file) " 的 daemon_pid 是空的或那支已經死了），"
                     "脫節子地 " (child :root) " 沒人替它走鐘。"
                     "下一步：(aos/daemon :start)，再呼叫一次"))
    (fsx/write-json (C/status-path result)
                    {:format_version 1 :state "failed" :reason "no_daemon"
                     :message msg :at (fsx/now-iso) :ext {:child (child :root)}})
    (errorf "%s" msg))
  (register! (child :root) result (caller :root) clean-args)
  handle)

(defn handle? [x] (and (table? x) (= :aos/handle (get x :kind))))

(defn status
  "handle 現在是哪一態：:pending／:done／:failed。"
  [h]
  (first (C/triple (h :result))))

(defn await-result
  ``等一個 handle 走到終局，回傳結果內容（三態同 aos/call）。
  max-ms 省略＝30 秒；等超過就照 spec 的 await_timeout 報錯。``
  [h &opt max-ms]
  (default max-ms 30000)
  (var left max-ms)
  (while (and (= :pending (status h)) (> left 0))
    (os/sleep 0.1)
    (-= left 100))
  (def [state st] (C/triple (h :result)))
  (case state
    :done (C/decode-out (h :result) (h :opts))
    :failed (errorf "脫節呼叫 %s 壞了：%s — %s\n狀態檔：%s"
                    (h :child) (or (st :reason) "failed")
                    (or (st :message) "") (C/status-path (h :result)))
    (errorf (string "等了 %d ms，%s 的結果落點 %s 還是空的（await_timeout，S-07-22）。\n"
                    "下一步：`aos daemon ls` 看那塊地的鐘起來了沒")
            max-ms (h :child) (h :result))))
