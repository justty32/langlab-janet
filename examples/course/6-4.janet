# 配合 course/6-4-match.md（與續篇 6-4b）

(print "== 常值與 _ ==")
(pp (match 0 0 "zero" _ "other"))   # "zero"
(pp (match 5 0 "zero" _ "other"))   # "other"

(print "== tuple 模式與綁定 ==")
(pp (match [:add 1 2] [:add a b] (+ a b) [:neg x] (- x)))   # 3
(pp (match [:neg 5]   [:add a b] (+ a b) [:neg x] (- x)))   # -5

(print "== 字典模式：子集比對 ==")
(pp (match {:kind :dog :age 3} {:kind k} k))                # :dog
(pp (match {:kind :dog} {:kind k :age a} a _ :no))          # :no，模式要的鍵值裡沒有
(pp (match {:kind :dog} {:kind :cat} :cat {:kind k} k))     # :dog

(print "== 守衛 ==")
(pp (match "hi" (s (string? s)) (string "str " s) _ :other))   # "str hi"
(pp (match 42   (s (string? s)) (string "str " s) _ :other))   # :other

(print "== 同名兩次＝要相等 ==")
(pp (match [1 1] [a a] :same _ :diff))   # :same
(pp (match [1 2] [a a] :same _ :diff))   # :diff

(print "== & 收尾、巢狀、array ==")
(pp (match [1 2 3 4] [a & rest] [a rest]))    # (1 (2 3 4))
(pp (match {:pos [3 4]} {:pos [x y]} (+ x y))) # 7
(pp (match @[1 2] [a b] [a b]))               # (1 2)
(pp (case @[1 2] @[1 2] :hit :miss))          # :miss，case 用 = 比身分

(print "== 坑：沒中又沒 _ ==")
(pp (match 99 0 :zero))   # nil

(print "== 坑：前綴比對 ==")
(pp (match [1 2 3] [a b] :two [a b c] :three))   # :two
(pp (match [1 2 3] [] :empty))                   # :empty
(pp (match [1] [a b] :two _ :other))             # :other，值比模式短才不中
(pp (match [1 2 3] [a b c] :three [a b] :two))   # :three，長的排前面
(defn exactly-two [v]
  (match v (t (and (indexed? t) (= 2 (length t)))) :exactly-two _ :other))
(pp (exactly-two [1 2]))     # :exactly-two
(pp (exactly-two [1 2 3]))   # :other

(print "== 小直譯器 ==")
(defn run [cmd]
  (match cmd
    [:add a b]            (+ a b)
    [:neg x]              (- x)
    {:op "mul" :a a :b b} (* a b)
    _                     :unknown))
(pp (map run [[:add 1 2] [:neg 5] {:op "mul" :a 2 :b 3} [:foo]]))   # @[3 -5 6 :unknown]

# ---- 練習解答 ----
(print "== 練習解答 ==")

# 1. 用 tuple 模式分辨形狀
(defn area [shape]
  (match shape
    [:square s] (* s s)
    [:rect w h] (* w h)
    _           :unknown))
(pp (area [:rect 2 3]))     # 6
(pp (area [:square 4]))     # 16
(pp (area [:circle 1]))     # :unknown

# 2. 字典模式，有 :name 才中
(defn greet [user]
  (match user
    {:name name} (string "hi " name)
    _            "hi stranger"))
(pp (greet {:name "ann" :age 9}))   # "hi ann"
(pp (greet {:age 9}))               # "hi stranger"

# 3. 前綴坑：長的排前面（或用守衛檢查長度）
(pp (match [1 2] [a b] :two [a] :one))   # :two
(pp (match [1]   [a b] :two [a] :one))   # :one
