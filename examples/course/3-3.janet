# 配合 course/3-3-相等與比較.md
# 跑法：janet examples/course/3-3.janet

(print "== 基本型別比內容 ==")
(pp (= 1 1))                   # true
(pp (= 1 1.0))                 # true
(pp (= "ab" (string "a" "b"))) # true
(pp (= :a :a))                 # true
(pp (= nil nil))               # true
(pp (= "1" 1))                 # false   不會偷偷轉型

(print "== tuple、struct 比內容 ==")
(pp (= [1 2] [1 2]))             # true
(pp (= {:a 1} {:a 1}))           # true
(pp (= [1 [2 3]] [1 [2 3]]))     # true   巢狀也一路比進去

(print "== array、table 比「是不是同一個」 ==")
(pp (= @[1 2] @[1 2]))       # false   兩個不同的 array
(pp (= @{:a 1} @{:a 1}))     # false
(def a @[1 2])
(def b a)                    # 沒複製，只是多一個名字
(pp (= a b))                 # true

(print "== 要比內容用 deep= ==")
(pp (deep= @[1 2] @[1 2]))                 # true
(pp (deep= @{:a @[1 2]} @{:a @[1 2]}))     # true
(pp (deep= [1 2] @[1 2]))                  # false   型別也要一樣
(pp (deep-not= @[1] @[2]))                 # true

(print "== 拿容器當字典的鍵：tuple 可以 ==")
(def 棋盤 @{})
(put 棋盤 [0 0] :king)
(put 棋盤 [7 7] :rook)
(pp (get 棋盤 [7 7]))   # :rook   新寫的 [7 7] 查得到
(pp (length 棋盤))      # 2

(print "== 拿容器當字典的鍵：array 會找不到 ==")
(def 壞棋盤 @{})
(put 壞棋盤 @[0 0] :king)
(pp (get 壞棋盤 @[0 0]))   # nil   放得進去，用新的 @[0 0] 查不到
(pp (length 壞棋盤))       # 1     東西確實在裡面
(def 鑰匙 @[1 1])
(put 壞棋盤 鑰匙 :queen)
(pp (get 壞棋盤 鑰匙))     # :queen   拿同一個 array 才找得到
(pp (freeze @[0 0]))       # (0 0)    要當鍵就先 freeze 成 tuple

(print "== 大小比較：< 和 compare ==")
(pp (< 1 2))                 # true
(pp (< "a" "b"))             # true
(pp (< [1 2] [1 3]))         # true   逐格比
(pp (compare 1 2))           # -1
(pp (compare [1 2] [1 2]))   # 0
(pp (sort @[[2 1] [1 9] [1 2]]))   # @[(1 2) (1 9) (2 1)]

(print "== 坑：tuple 裡包 array ==")
(pp (= [1 @[2 3]] [1 @[2 3]]))      # false   第二格是兩個不同的 array
(pp (deep= [1 @[2 3]] [1 @[2 3]]))  # true

(print "== 坑：index-of 也是用 = ==")
(pp (index-of @[1 2] @[@[1 2]]))          # nil
(pp (index-of [1 2] @[[1 2] [3 4]]))      # 0

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 座標當鍵
(def 地圖 @{})
(put 地圖 [0 0] "home")
(put 地圖 [1 0] "shop")
(put 地圖 [0 1] "park")
(each 座標 [[0 0] [1 0] [0 1]]
  (printf "%j -> %s" 座標 (get 地圖 座標)))
# (0 0) -> home  /  (1 0) -> shop  /  (0 1) -> park

# 2. = 與 deep=
(def x @{:a @[1]})
(def y @{:a @[1]})
(pp (= x y))       # false   x 和 y 是兩個不同的 table
(pp (deep= x y))   # true    內容從外到內都一樣

# 3. 排序 tuple
(pp (sort @[["Bob" 30] ["Ann" 30] ["Cid" 25]]))
# @[("Ann" 30) ("Bob" 30) ("Cid" 25)]   第一格是名字，先比名字
(pp (sort @[[30 "Bob"] [30 "Ann"] [25 "Cid"]]))
# @[(25 "Cid") (30 "Ann") (30 "Bob")]   第一格是年齡，先比年齡，同年齡再比名字
