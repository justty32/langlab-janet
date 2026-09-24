# 配合 course/7-1-錯誤怎麼丟怎麼接.md 與 7-1b-往上丟與回-nil.md
#   janet examples/course/7-1.janet

(print "== 丟出去：error ==")
# 直接 (error "boom") 會讓整支程式停下來，所以這裡先用 protect 包著看它的樣子
(printf "%j" (protect (error "boom")))

(print "== 接住：try ==")
(print (try
         (error "boom")
         ([e] (string "接到了 " e))))
(printf "沒炸時回 body 的值：%j" (try (+ 1 2) ([e] :caught)))

(print "== 不想寫 try：protect ==")
(printf "%j" (protect (+ 1 2)))
(printf "%j" (protect (error "bad")))
(def [ok v] (protect (error "bad")))
(printf "拆開來：ok=%j v=%j" ok v)

(print "== 帶格式的錯誤訊息：errorf ==")
(printf "%j" (protect (errorf "file %s missing (code %d)" "a.txt" 2)))

(print "== 卡住前提：assert ==")
(printf "%j" (protect (assert (= 1 2) "should be equal")))
(printf "%j" (protect (assert (= 1 2))))
(printf "檢查過關時回被檢查的值：%j" (assert 5 "never shown"))

(print "== 錯誤可以是任何值：丟 table 就能帶欄位 ==")
(printf "%j" (try
               (error {:code 404 :path "/users/9"})
               ([e] (e :code))))
(printf "整個接回來：%j" (try (error {:code 404 :path "/users/9"}) ([e] e)))

(print "== 接到但不想處理：propagate ==")
(printf "%j" (protect
               (try
                 (error {:code 500})
                 ([e f] (if (= 500 (e :code)) (propagate e f) :handled)))))
(printf "%j" (protect
               (try
                 (error {:code 404})
                 ([e f] (if (= 500 (e :code)) (propagate e f) :handled)))))
(printf "往上丟前補說明：%j"
        (protect (try (slurp "config.json")
                   ([e] (errorf "startup failed: %s" e)))))

(print "== 什麼時候回 nil，什麼時候拋錯 ==")
(printf "string/find 查不到：%j" (string/find "z" "abc"))
(printf "scan-number 轉不了：%j" (scan-number "abc"))
(printf "os/stat 檔案不在：%j" (os/stat "nope"))
(printf "slurp 讀不到就炸：%j" (protect (slurp "nope.txt")))

(print "== 坑：接到的不一定是字串 ==")
(printf "%j" (try (error @{:code 404}) ([e] (string/has-prefix? "<table" (string e)))))
(print "所以要印就用 %j：")
(printf "%j" (try (error @{:code 404}) ([e] e)))

(print "== 坑：assert 永遠會跑 ==")
(printf "%j" (protect (assert (number? "abc") "want a number")))

# ---- 練習解答 ----
(print "== 練習 1：safe-div ==")
(defn safe-div [a b]
  (if (= b 0)
    (error {:code :div-by-zero :a a})
    (/ a b)))
(printf "%j" (safe-div 10 4))
(try (safe-div 1 0)
  ([e] (printf "接到 code=%j a=%j" (e :code) (e :a))))

(print "== 練習 2：parse-age（拋錯版）==")
(defn parse-age [s]
  (def n (scan-number s))
  (unless (and n (<= 0 n 150))
    (errorf "bad age: %j" s))
  n)
(printf "%j" (protect (parse-age "42")))
(printf "%j" (protect (parse-age "abc")))
(printf "%j" (protect (parse-age "999")))

(print "== 練習 3：parse-age?（回 nil 版）==")
(defn parse-age? [s]
  (def n (scan-number s))
  (if (and n (<= 0 n 150)) n nil))
(printf "%j" (parse-age? "42"))
(printf "%j" (parse-age? "abc"))
# 呼叫端寫起來的差別：回 nil 版直接接 if，拋錯版要包 try 或 protect
(if-let [age (parse-age? "abc")]
  (printf "年齡 %d" age)
  (print "不是合法年齡"))
