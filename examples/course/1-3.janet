# 配合 course/1-3-值有哪幾種.md
# 每段用 %j 印出值，跟課文的 # => 寫法一樣。

(defn show [label v]
  (print label "  => " (string/format "%j" v)))

(print "== 數字 ==")
(show "(type 42)" (type 42))
(show "(type 3.14)" (type 3.14))
(show "(/ 7 2)" (/ 7 2))
(show "(= 3 3.0)" (= 3 3.0))

(print "== 字串 ==")
(show "(type \"hello\")" (type "hello"))
(print "你好，Janet")

(print "== keyword ==")
(show ":abc" :abc)
(show "(type :abc)" (type :abc))

(print "== symbol ==")
(show "'abc" 'abc)
(show "(type 'abc)" (type 'abc))
# 直接寫 abc 會在編譯時就出錯，所以用 eval-string 包起來再 protect
(show "直接求值 abc" (protect (eval-string "abc")))

(print "== nil 與 true／false ==")
(show "(type nil)" (type nil))
(show "(type true)" (type true))
(show "(type false)" (type false))
(show "(< 1 2)" (< 1 2))

(print "== 什麼算真、什麼算假 ==")
(print "0     -> " (if 0 "真" "假"))
(print "\"\"    -> " (if "" "真" "假"))
(print "nil   -> " (if nil "真" "假"))
(print "false -> " (if false "真" "假"))

(print "== 坑：keyword 跟字串不相等 ==")
(show "(= \"abc\" :abc)" (= "abc" :abc))
(show "(= \"abc\" (string :abc))" (= "abc" (string :abc)))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 6 除以 2 除得盡，結果印成 3，型別仍是 number（整數小數同一種）
(show "(type (/ 6 2))" (type (/ 6 2)))
(show "(/ 6 2)" (/ 6 2))
# 2. 兩個都是真：0.0 是數字不是 nil/false；:false 是 keyword，不是 false 本人
(print "0.0    -> " (if 0.0 "真" "假"))
(print ":false -> " (if :false "真" "假"))
# 3. type 回的是 keyword，所以型別的型別是 :keyword
(show "(type (type 1))" (type (type 1)))
