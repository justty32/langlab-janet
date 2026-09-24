# 配合 course/6-2-閉包與高階函式.md（續篇 6-2b）

(print "== fn：沒有名字的函式 ==")
(def 加倍 (fn [x] (* x 2)))
(print (加倍 21))
(print (type 加倍))

(print "== 函式放進 array ==")
(def 步驟 @[(fn [x] (+ x 1)) (fn [x] (* x 10))])
(print ((get 步驟 0) 5) " " ((get 步驟 1) 5))

(print "== 把函式當引數 ==")
(defn 做兩次 [f x] (f (f x)))
(print (做兩次 (fn [x] (* x 3)) 2))

(print "== map：每張發票加 5% 稅 ==")
(pp (map (fn [金額] (/ (* 金額 105) 100)) [100 200 40]))

(print "== filter：挑超過 100 的 ==")
(pp (filter (fn [金額] (> 金額 100)) [50 120 300 80]))

(print "== reduce：收據加總 ==")
(print (reduce + 0 [120 45 300]))
(print (reduce (fn [累積 x] (+ 累積 x)) 0 [1 2 3]))

(print "== | 短寫 ==")
(pp (map |(* $ 2) [1 2 3]))
(pp (filter |(> $ 100) [50 120]))
(print (|(+ $0 $1) 3 4))
(pp (|$& 1 2 3))

(print "== 閉包：計數器 ==")
(defn 做計數器 []
  (var n 0)
  (fn [] (++ n)))
(def c1 (做計數器))
(def c2 (做計數器))
(c1)
(c1)
(print "c1 第三次：" (c1))
(print "c2 第一次：" (c2))

(print "== 記住的是變數本身 ==")
(var x 1)
(def f (fn [] x))
(set x 2)
(print (f))

(print "== 吐函式的函式 ==")
(defn 做加法器 [n]
  (fn [x] (+ x n)))
(def 加十 (做加法器 10))
(def 加一 (做加法器 1))
(print (加十 5) " " (加一 5))

(print "== 坑：while 裡建閉包 ==")
(def gs @[])
(var j 0)
(while (< j 3)
  (array/push gs (fn [] j))
  (++ j))
(pp (map |($) gs))

(print "== 解法一：seq 每圈新綁定 ==")
(def fs (seq [i :range [0 3]] (fn [] i)))
(pp (map |($) fs))

(print "== 解法二：圈內 let 抄一份 ==")
(def hs @[])
(var k 0)
(while (< k 3)
  (let [kk k] (array/push hs (fn [] kk)))
  (++ k))
(pp (map |($) hs))

# ---- 練習解答 ----

(print "== 練習 1：偶數平方 ==")
(pp (map |(* $ $) (filter even? [1 2 3 4 5 6])))

(print "== 練習 2：編號機 ==")
(defn 做編號機 []
  (var 目前 0)
  (fn [] (++ 目前)))
(def 甲 (做編號機))
(def 乙 (做編號機))
(print (甲) " " (甲) " " (甲) " / " (乙))

(print "== 練習 3：reduce 找最大 ==")
(def 數們 [3 9 2 7])
(print (reduce max (first 數們) 數們))
