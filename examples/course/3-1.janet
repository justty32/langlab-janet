# 配合 course/3-1-四個容器.md
# 跑法：janet examples/course/3-1.janet

(print "== 建出來、看型別 ==")
(def 一串固定的 [1 2 3])
(def 一串可改的 @[1 2 3])
(def 一組固定的 {:name "小明" :age 30})
(def 一組可改的 @{:name "小明" :age 30})
(print (type 一串固定的))   # :tuple
(print (type 一串可改的))   # :array
(print (type 一組固定的))   # :struct
(print (type 一組可改的))   # :table

(print "== 印出來長什麼樣 ==")
(pp [1 2 3])    # (1 2 3)   寫的時候用中括號，印出來是小括號
(pp @[1 2 3])   # @[1 2 3]
(pp {:a 1})     # {:a 1}
(pp @{:a 1})    # @{:a 1}

(print "== 用函式建 ==")
(pp (tuple 1 (+ 1 1) 3))   # (1 2 3)
(pp (array 1 2 3))         # @[1 2 3]
(pp (struct :a 1))         # {:a 1}
(pp (table :a 1))          # @{:a 1}

(print "== 拿一個出來、數有幾個 ==")
(def 水果 ["apple" "banana" "guava"])
(print (水果 0))        # apple   位置從 0 數起
(print (水果 2))        # guava
(def 人 @{:name "小明" :age 30})
(print (人 :age))       # 30
(print (length 水果))   # 3
(print (length 人))     # 2

(print "== 不可變的真的改不了 ==")
(def 可改 @[1 2 3])
(array/push 可改 4)
(pp 可改)   # @[1 2 3 4]   直接改了它本身
(def 固定 [1 2 3])
(def [成功? 錯誤] (protect (array/push 固定 4)))
(print "成功嗎：" 成功?)   # false
(print "錯誤訊息：" 錯誤)  # bad slot #0, expected array, got <tuple 0x...>

(print "== 鍵值對沒有順序 ==")
(pp (keys @{:a 1 :b 2 :c 3}))   # @[:b :a :c]   不是你寫的順序

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. tuple 放三個城市，取第二個（位置 1）
(def 城市 ["台北" "台中" "高雄"])
(print (城市 1))   # 台中

# 2. table 放兩對，確認長度
(def 專案 @{:lang "Janet" :year 2026})
(print (length 專案))   # 2

# 3. 四個空容器的型別
(print (type @{}))   # :table
(print (type {}))    # :struct
(print (type @[]))   # :array
(print (type []))    # :tuple
