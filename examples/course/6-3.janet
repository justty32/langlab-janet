# 配合 course/6-3-執行緒巨集與解構.md（與續篇 6-3b）

(print "== 巢狀 vs -> ==")
(pp (inc (* (+ 5 3) 2)))          # 17
(pp (-> 5 (+ 3) (* 2) inc))       # 17，同一件事

(print "== -> 塞第一個參數 ==")
(pp (-> "hello" string/ascii-upper (string "!")))   # "HELLO!"

(print "== ->> 塞最後一個參數 ==")
(pp (->> [1 2 3 4] (map inc) (filter even?)))       # @[2 4]

(print "== -?> 遇到 nil 就停 ==")
(pp (-?> nil (get :a)))                    # nil
(pp (-?> {:a {:b 7}} (get :a) (get :b)))   # 7
(pp (-?> {:a 1} (get :x) (+ 1)))           # nil
(pp (protect (-> {:a 1} (get :x) (+ 1))))  # 普通 -> 會真的去算 (+ nil 1)
(pp (as-> 5 $ (+ $ 1) (* $ $)))            # 36

(print "== 坑：-> 與 ->> 選錯 ==")
(pp (-> 2 (- 10)))                # -8
(pp (->> 2 (- 10)))               # 8
(pp (macex1 '(-> 2 (- 10))))      # (- 2 10)
(pp (macex1 '(->> 2 (- 10))))     # (- 10 2)

(print "== 沒有解構時 ==")
(def pt [3 4])
(pp (+ (* (get pt 0) (get pt 0)) (* (get pt 1) (get pt 1))))   # 25

(print "== 拆 tuple / array ==")
(let [[a b] [1 2]] (pp [a b]))                  # (1 2)
(let [[a & rest] [1 2 3 4]] (pp [a rest]))      # (1 (2 3 4))

(print "== 拆 struct / table ==")
(let [{:x x :y y} {:x 1 :y 2}] (pp [x y]))      # (1 2)

(print "== 巢狀 ==")
(let [[x [y z]] [1 [2 3]]] (pp [x y z]))        # (1 2 3)

(print "== 函式參數與 each ==")
(defn f [[a b] {:k k}] [a b k])
(pp (f [1 2] {:k 9}))                           # (1 2 9)
(each [k v] (pairs {:a 1}) (print k " = " v))   # a = 1

(print "== 坑：不夠補 nil、字串拆出 byte ==")
(let [[x y z] [1 2]] (pp [x y z]))              # (1 2 nil)
(let [{:zz q} {:a 1}] (pp q))                   # nil
(let [[c1 c2] "ab"] (pp [c1 c2]))               # (97 98)

(print "== 兩個一起用 ==")
(def [first-big second-big]
  (->> [5 3 8 1 9 2] (filter |(> $ 2)) sort))
(pp [first-big second-big])                     # (3 5)

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 先 trim 再轉大寫
(pp (-> "  hi  " string/trim string/ascii-upper))       # "HI"
# 2. 資料處理串接，資料放最後，用 ->>
(pp (->> [1 2 3] (map |(* $ 10)) (reduce + 0)))          # 60
# 3. 參數位置直接拆字典
(defn dist2 [{:x x :y y}] (+ (* x x) (* y y)))
(pp (dist2 {:x 3 :y 4}))                                  # 25
