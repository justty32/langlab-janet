# 配合 course/4-3-JSON.md
# 跑法：janet examples/course/4-3.janet

(import spork/json)

(print "== encode：資料變文字 ==")
(printf "%q" (json/encode {:name "Bob" :n 3}))
(print (json/encode {:name "Bob" :n 3}))
(print (json/encode {:name "Bob" :ids [1 2]} "  " "\n"))
(print (json/encode @{:list @[1 2]}))
(print (json/encode {:a :k}))
(printf "%q" (protect (json/encode {:f (fn [] 1)})))

(print "== decode：文字變資料 ==")
(def d (json/decode "{\"name\":\"Bob\",\"tags\":[\"a\",\"b\"]}" true))
(printf "%q" d)
(print (get d :name))
(print (get-in d [:tags 1]))
(print (type d))
(printf "%q" (protect (json/decode "{bad")))

(print "== null 跟 nil ==")
(print (json/encode {:a nil :b 1}))
(print (json/encode {:a :null}))
(print (json/decode "null"))
(printf "%q" (json/decode "null" true true))
(print (get (json/decode "{\"a\":1,\"b\":null}" true) :b))
(printf "%q" (json/decode "{\"a\":1,\"b\":null}" true true))

(print "== 存到檔案、讀回來 ==")
# 寫到暫存目錄，跑完就刪，不留垃圾
(def path (string (os/getenv "TMPDIR" "/tmp") "/course-4-3-cfg.json"))
(spit path (json/encode @{:debug true} "  " "\n"))
(def back (json/decode (slurp path) true))
(print (get back :debug))
(os/rm path)

(print "== 坑：忘了給 true ==")
(def d2 (json/decode "{\"name\":\"Bob\"}"))
(printf "%q" d2)
(printf "%q" (get d2 :name))
(print (get d2 "name"))

(print "== 坑：中文變 \\uXXXX ==")
(print (json/encode {:cond "晴"}))
(print (get (json/decode (json/encode {:cond "晴"}) true) :cond))

(print "== 坑：encode 回 buffer ==")
(print (= (json/encode {:a 1}) "{\"a\":1}"))
(print (= (string (json/encode {:a 1})) "{\"a\":1}"))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1
(print (json/encode @{:title "買牛奶" :done false} "  " "\n"))
# 2
(def items (json/decode "[{\"n\":\"A\"},{\"n\":\"B\"}]" true))
(print (get-in items [1 :n]))
# 3
(def r (json/decode "{\"a\":null}" true))
(when (= (get r :a) :null)
  (print "a 是空的"))
