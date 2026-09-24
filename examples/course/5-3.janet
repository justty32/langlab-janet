# 配合 course/5-3-沒有-return.md

(print "== 最後一個值就是回傳值 ==")
(defn sign [n]
  (cond (< n 0) :neg (zero? n) :zero :pos))
(printf "%j" (map sign [-5 0 3]))

(print "== 真的要中途離開函式：break ==")
(defn safe-div [a b]
  (when (zero? b) (break :div-by-zero))
  (/ a b))
(printf "%j" (safe-div 1 0))
(printf "%j" (safe-div 6 3))

(print "== 帶值出迴圈：var 加 break ==")
(defn first-big [xs]
  (var found nil)
  (each x xs (when (> x 10) (set found x) (break)))
  found)
(printf "%j" (first-big [3 12 40]))
(printf "%j" (first-big [1 2]))
(printf "%j" (find |(> $ 10) [3 12 40]))
(printf "%j" (some |(> $ 10) [3 12 40]))

(print "== 沒有 continue：用過濾 ==")
(printf "%j" (seq [i :range [0 6] :unless (= i 2)] i))
(def r @[])
(each x [1 2 3 4] (unless (even? x) (array/push r x)))
(printf "%j" r)

(print "== 跳出兩層迴圈：label 加 return ==")
(printf "%j"
  (label out
    (for i 0 3
      (for j 0 3
        (when (= [i j] [1 2]) (return out [i j]))))))
(printf "%j"
  (label out
    (for i 0 3 (when (= i 9) (return out i)))
    :none))
(printf "%j" (protect (eval '(label out (return nowhere 1)))))
(defn find-pair [target]
  (label done
    (for i 0 5
      (for j 0 5
        (when (= (+ i j) target) (return done [i j]))))
    nil))
(printf "%j" (find-pair 3))
(printf "%j" (find-pair 99))

(print "== 坑一：迴圈裡的 break 不會離開函式 ==")
(defn f [] (each x [1 2 3] (when (= x 2) (break))) :done)
(printf "%j" (f))

(print "== 坑二：迴圈裡 break 的值會不見 ==")
(printf "%j" (each x [1 2 3] (when (= x 2) (break x))))
(printf "%j" (while true (break 42)))

# ---- 練習解答 ----
(print "== 練習解答 ==")

# 1. 用 cond 分支，不用 break
(defn clamp [n]
  (cond (< n 0) 0
        (> n 100) 100
        n))
(printf "%j" (map clamp [-5 50 200]))

# 2. var 加 break 一次，find 一次
(defn first-neg [xs]
  (var found nil)
  (each x xs (when (neg? x) (set found x) (break)))
  found)
(defn first-neg2 [xs] (find neg? xs))
(printf "%j %j" (first-neg [3 -1 -7]) (first-neg [1 2]))
(printf "%j %j" (first-neg2 [3 -1 -7]) (first-neg2 [1 2]))

# 3. label 加 return 跳出兩層
(defn find-zero [g]
  (label found
    (for row 0 (length g)
      (for col 0 (length (g row))
        (when (zero? ((g row) col)) (return found [row col]))))
    nil))
(printf "%j" (find-zero [[1 2 3] [4 0 6] [7 8 0]]))
(printf "%j" (find-zero [[1 2] [3 4]]))
