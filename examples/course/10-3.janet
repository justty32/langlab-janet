# 配合 course/10-3-PEG.md
(defn show [x] (print (string/format "%j" x)))

(print "== 從一個數字開始 ==")
(show (peg/match "42" "42"))
(show (peg/match "42" "43"))
(show (peg/match ~(range "09") "7"))
(show (peg/match ~(range "09") "x"))
(show (peg/match ~(some (range "09")) "123abc"))
(show (peg/match ~(<- (some (range "09"))) "123abc"))
(show (peg/match ~(* (<- (some (range "09"))) -1) "123abc"))
(show (peg/match ~(* (<- (some (range "09"))) -1) "123"))
(show (peg/match ~(/ (<- (some (range "09"))) ,scan-number) "123"))

(print "== 拼成 key=value ==")
(def word ~(<- (some (range "az"))))
(def num ~(/ (<- (some (range "09"))) ,scan-number))
(show (peg/match ~(* ,word "=" ,num -1) "port=8080"))
(show (peg/match ~(* ,word "=" ,num -1) "port=abc"))

(def kv ~{:key (<- (some (+ (range "az") "_")))
          :num (/ (<- (some (range "09"))) ,scan-number)
          :main (* :key "=" :num -1)})
(show (peg/match kv "max_conn=10"))

(def lines ~{:key (<- (some (+ (range "az") "_")))
             :val (<- (some (if-not "\n" 1)))
             :pair (group (* :key "=" :val))
             :main (* (some (* :pair (? "\n"))) -1)})
(def cfg-text "host=example.com\nport=8080")
(show (peg/match lines cfg-text))
(show (from-pairs (peg/match lines cfg-text)))

(print "== 常用積木：find、find-all、replace-all ==")
(show (peg/find ~(some (range "09")) "abc123"))
(show (peg/find-all "a" "banana"))
(show (peg/replace-all ~(some (range "09")) "#" "a1b22c333"))
(show (string (peg/replace-all ~(some (range "09")) "#" "a1b22c333")))

(print "== 坑 ==")
(show (nil? (peg/match ~(some (range "az")) "123")))
(show (protect (peg/match (range "09") "7")))
(show (peg/match '(/ (<- (some (range "09"))) ,scan-number) "1"))
(show (peg/match ~(* (+ "ab" "abc") -1) "abc"))
(show (peg/match ~(* (+ "abc" "ab") -1) "abc"))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 解析日期
(def date ~{:n (/ (<- (some (range "09"))) ,scan-number)
            :main (* :n "-" :n "-" :n -1)})
(show (peg/match date "2026-09-24"))
# 2. 逗號切開並去空白
(def csv ~{:ws (any " ")
           :item (<- (some (if-not (set ", ") 1)))
           :main (* :ws :item (any (* :ws "," :ws :item)) :ws -1)})
(show (peg/match csv "a, b,c ,d"))
