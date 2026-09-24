# 配合 course/5-2-迴圈.md

(print "== each ==")
(each x [10 20 30]
  (print x))

(print "== eachp ==")
(eachp [k v] {:apple 3 :pear 5}
  (print k " 有 " v " 個"))

(print "== for ==")
(for i 0 3
  (print i))

(print "== while ==")
(var i 0)
(while (< i 3)
  (print i)
  (++ i))
(print "i 最後是 " i)

(print "== loop ==")
(loop [i :range [0 3]] (print i))
(loop [x :in [:a :b]] (print x))
(loop [[k v] :pairs {:a 1}] (print k v))
(loop [i :range [0 6] :when (even? i)]
  (print i))
(pp (loop [x :in [1 2]] x))
(loop [x :range [0 2]  y :in [:a :b]]
  (print x y))

(print "== seq ==")
(pp (seq [i :range [0 6] :when (even? i)] i))
(pp (seq [x :in [1 2 3]] (* x x)))
(def sq (tabseq [x :in [1 2 3]] x (* x x)))
(print (sq 3) " " (length sq))

(print "== 坑 ==")
(each c "ab" (print c))
(pp (seq [c :in "ab"] (string/from-bytes c)))
(pp (seq [i :range [3 0 -1]] i))
(pp (seq [i :down [3 0]] i))
(pp (seq [i :range [1 3]] i))
(pp (seq [i :range-to [1 3]] i))

# ---- 練習解答 ----
(print "== 練習 ==")
# 1. 1 到 10 裡 3 的倍數
(pp (seq [n :range-to [1 10] :when (zero? (% n 3))] n))
# 2. 加總
(var sum 0)
(each x [3 5 7] (+= sum x))
(print sum)
# 3. 從 5 倒數到 1
(loop [n :down [5 0]] (print n))
