# 「一塊地＝一支程式」那半：把子地包成 Janet 函式。
# 同步呼叫（spec 07 S-07-02、S-07-09～S-07-14）、三態、脫節呼叫與 await。
# 呼叫方（父）＝ lib 的暫存區那塊地（land/workspace）：呼叫記錄寫在它的 .aos/calls/，
# 預設結果落點也配在它裡面。⚠ spec 沒有「呼叫方不是一塊地」這一態，見 findings 第 1 條。

(import spork/json)
(import spork/path)
(import ./fsx)
(import ./land :as L)
(import ./proc :as P)

(defn status-path [result] (string result ".status.json"))
(defn usage-path  [result] (string result ".usage.json"))
(defn triple
  ``三態（S-07-14）：狀態檔在＝:failed（贏過結果檔）、結果檔在＝:done、都不在＝:pending。
  回 [態 狀態檔內容或 nil]。``
  [result]
  (def sp (status-path result))
  (def st (fsx/read-json sp))
  (cond
    st [:failed st]
    (fsx/exists? sp) [:failed {:reason "invalid_status" :message "狀態檔不是合法 JSON"}]
    (fsx/exists? result) [:done nil]
    [:pending nil]))

(defn- check-result-path [caller result]
  (def root (os/realpath (caller :root)))
  (def dir (os/realpath (path/dirname (path/abspath result))))
  (unless dir
    (errorf "結果落點的父資料夾不在：%s。下一步：先建好這個資料夾" (path/dirname result)))
  (def resolved (path/join dir (path/basename result)))
  (unless (or (= resolved root) (string/has-prefix? (string root "/") resolved))
    (errorf "結果落點 %s 不在呼叫方 %s 裡（S-07-57）" resolved root))
  (when (string/find "/.aos/" (string resolved "/"))
    (errorf "結果落點 %s 落在某塊地的 .aos/ 裡（S-07-58 禁止）。下一步：換一條頂層的路徑" resolved))
  (each suf [".status.json" ".usage.json"]
    (when (string/has-suffix? suf resolved)
      (errorf "結果落點 %s 用了保留後綴 %s（S-07-59）" resolved suf)))
  (each p [resolved (status-path resolved) (usage-path resolved)]
    (when (fsx/exists? p)
      (errorf (string "結果落點旁邊已經有檔：%s（S-07-61 禁止自動蓋掉）。\n"
                      "下一步：人自己刪掉它，或這次呼叫改帶 :result 換一條路徑") p)))
  resolved)

(defn alloc-result [caller opts id]
  (def r (or (opts :result) (path/join "out" (string id ".out"))))
  (check-result-path caller (L/resolve-in caller r)))

(defn call-record! [caller child mode result args id]
  (def rec {:format_version 1 :id id :tick 0
            :series "janet" :step "call"
            :child (child :root) :mode (string mode)
            :result result :args (or args {}) :opened_at (fsx/now-iso)})
  (fsx/write-json (path/join (caller :calls) (string id ".json")) rec)
  rec)

(defn- child-env [result caller args]
  (def e @{"AOS_RESULT" result "AOS_CALLER" (caller :root)})
  (eachp [k v] (or args {})
    (put e (string "AOS_ARG_" (string/ascii-upper (string k))) (string v)))
  e)

(defn decode-out
  "讀結果檔。⚠ slurp 回的是 buffer 不是 string，一定要 (string …)，不然 = 比不相等。"
  [result opts]
  (def raw (string (slurp result)))
  (if (opts :json) (json/decode raw true) raw))

(defn- fail! [result st child]
  (errorf (string "子地 %s 的呼叫壞了：%s — %s\n狀態檔：%s\n下一步：看那個檔的 message，"
                  "修好之後刪掉結果落點與狀態檔再呼叫一次")
          child (or (st "reason") (st :reason) "failed")
          (or (st "message") (st :message) "（狀態檔沒寫 message）")
          (status-path result)))

(defn rearm!
  ``呼叫「同一塊地」第二次之前一定要做的事。

  ⚠ 一塊地跑完之後 `.aos/series.json` 的串是 `done`，再 `aos run` 一次只會立刻回
    「閒著了」，**什麼都不做也不報錯**——所以「資料夾當函式」呼叫第二次會靜默拿不到結果。
    spec 沒有「把一塊地倒帶再跑一次」這個動作（`aos reset` 只清 failed／stopped 的串），
    所以這裡直接把接力棒刪掉，讓載入器下一格重開一條串。詳見 findings 第 2 條。

  有 failed／stopped 的串時先 `aos reset`（那是 spec 給的動作），再刪接力棒。``
  [l]
  (def target (L/land l))
  (def baton (fsx/read-json (target :series)))
  (when baton
    (def sts (map |(get $ :status) (or (baton :series) [])))
    (when (some |(not= "done" $) sts)
      (P/aos-run ["reset" (target :root)]))
    (protect (os/rm (target :series)))
    (protect (os/rm (path/join (target :aos) "stopped.json"))))
  target)

(defn- registry-clash [child]
  # ⚠ `aos run` 會拿登記表那筆的 result／parent／args 蓋掉行程環境裡的 AOS_RESULT，
  #   所以子地若還留著一筆登記，結果會**靜默**寫到舊落點去。findings 第 4 條。
  (def home (or (os/getenv "AOS_HOME") (os/getenv "HOME")))
  (def reg (fsx/read-json (path/join home ".aos" "registry.json") {}))
  (find |(= (get $ :path) (child :root)) (or (reg :entries) [])))

(defn call
  ``同步呼叫一塊地：把 args 變成子地的 AOS_ARG_*，推它走到閒著，再照三態讀結果。

  (aos/call "sub/" {:who "janet"})            # → 結果檔的內容（字串）
  (aos/call "sub/" {} {:json true})           # → json 解析過的 table
  opts：:result 落點（相對就以呼叫方那塊地為原點）、:json、:budget、:timeout-ms、
        :on-missing（結果與狀態檔都沒有時要 :error 還是 :nil，預設 :error）。``
  [l &opt args opts]
  (default args {})
  (default opts {})
  (def clean-args (fsx/string-args args))
  (def child (L/land l))
  (def caller (L/workspace))
  (def clash (registry-clash child))
  (when (and clash (get clash :result))
    (errorf (string "%s 在登記表裡還留著一筆（state %s，落點 %s）。\n"
                    "`aos run` 會拿那筆的 result 蓋掉這次呼叫的 AOS_RESULT，結果會寫錯地方。\n"
                    "下一步：先 `aos stop %s`，再把 $AOS_HOME/.aos/registry.json 那筆刪掉")
            (child :root) (get clash :state) (get clash :result) (child :root)))
  (unless (= false (opts :rearm)) (rearm! child))
  (def id (fsx/new-id))
  (def result (alloc-result caller opts id))
  (call-record! caller child :sync result clean-args id)
  (def r (P/run-land (child :root)
                     (merge opts {:env (child-env result caller clean-args)})))
  (def [state st] (triple result))
  (case state
    :done (decode-out result opts)
    :failed (fail! result st (child :root))
    (do
      (def msg (string "子地 " (child :root) " 已經閒著，結果落點 " result
                       " 卻兩個檔都沒有＝no_result（S-07-77）。"))
      (def st @{:format_version 1 :state "failed" :reason "no_result"
                :message msg :at (fsx/now-iso) :ext {:run-reason (or (r :reason) "?")}})
      (fsx/write-json (status-path result) st)
      (if (= :nil (opts :on-missing)) nil (fail! result st (child :root))))))

(defn land-fn
  ``把一塊地包成 Janet 函式——「資料夾當函式」的糖。

  (def greet (aos/fn "sub/"))
  (greet {:who "janet"})   # 等於 (aos/call "sub/" {:who "janet"})``
  [l &opt opts]
  (default opts {})
  (def target (L/land l))
  (fn [&opt args more] (call target (or args {}) (merge opts (or more {})))))

(defn decode-json "json 字串 → table（給 async 那支共用）。" [raw] (json/decode raw true))
