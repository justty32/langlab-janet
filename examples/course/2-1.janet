# 配合 course/2-1-把東西存起來.md
# 跑法：janet examples/course/2-1.janet

(print "== def ==")
(def price 100)
(def total (* price 3))
(print total)                     # 300

(print "== var 與 set ==")
(var count 0)
(set count (+ count 1))
(set count (+ count 1))
(print count)                     # 2
# var 沒給初始值會在讀程式的階段就錯，所以用 eval 包起來才示範得出來
(pp (protect (eval '(var y))))    # (false "expected at least 2 arguments to var")

(print "== 對 def 的東西 set 會怎樣 ==")
(pp (protect (eval '(do (def x 1) (set x 2)))))   # (false "cannot set constant")

(print "== let，暫時的名字 ==")
(print (let [a 1 b 2] (+ a b)))   # 3
(pp (protect (eval '(do (let [a 1] a) a))))       # (false "unknown symbol a")
(var n 0)
(set n (+ n 1))
(print n)                         # 1
(print (let [n 100] n))           # 100
(print n)                         # 1，外面的 n 沒被動到

(print "== 作用域 ==")
(defn f []
  (def inner 5)
  inner)
(print (f))                       # 5
(pp (protect (eval 'inner)))      # (false "unknown symbol inner")

(print "== 同名再 def 一次 ==")
(def x 1)
(def x 2)
(print x)                         # 2
(def [a b] [1 2])
(print a " " b)                   # 1 2

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. def 算面積
(def width 4)
(def height 5)
(def area (* width height))
(print area)                      # 20

# 2. var 連加
(var sum 0)
(set sum (+ sum 10))
(set sum (+ sum 20))
(set sum (+ sum 30))
(print sum)                       # 60

# 3. let 暫時蓋住外面的 var
(var m 1)
(print (let [m 99] m))            # 99
(print m)                         # 1
