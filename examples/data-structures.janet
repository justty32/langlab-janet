# 配合 docs/02-資料結構.md
#
#   janet examples/data-structures.janet
#
# 四個容器、一個 @ 的差別，以及那些「你以為會這樣」的地方。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-32s => %j" 說明 結果))

(節 "一個 @ 就是可變與不可變的差別")
(each [n v] [["@[1 2 3]  array" @[1 2 3]]
             ["[1 2 3]   tuple" [1 2 3]]
             ["@{:a 1}   table" @{:a 1}]
             ["{:a 1}    struct" {:a 1}]]
  (printf "  %-20s type=%-8j 可變？%s" n (type v)
          (if (or (array? v) (table? v)) "是" "否")))

(節 "取值：索引／鍵可以直接放在呼叫位置")
(def arr @[10 20 30])
(def tbl @{:k 9 "s" 8})
(秀 "(arr 0)" (arr 0))
(秀 "(tbl :k)" (tbl :k))
(秀 "(get tbl :missing :預設)" (get tbl :missing :預設))
(秀 "(length arr)" (length arr))

(print "\n  ⚠ 但負索引不能直接用（Python 出身的人一定會試）：")
(printf "  %-32s => %s" "(arr -1)" (try (arr -1) ([e] (string "報錯：" e))))
(秀 "(array/slice arr -2)  ← 這個吃負數" (array/slice arr -2))
(秀 "(last arr)  ← 要最後一個就用它" (last arr))

(節 "原地改 vs 給你新的")
(def a @[1 2 3])
(array/push a 4)
(秀 "(array/push a 4) 之後 a" a)
(秀 "(map |(* $ $) a)  ← 回新的" (map |(* $ $) a))
(秀 "  a 沒變" a)
(def t @{:n 1})
(put t :n 2)
(秀 "(put t :n 2) 之後 t" t)

(節 "⚠ = 對不可變比內容，對可變比身分")
(秀 "(= [1 2] [1 2])    tuple" (= [1 2] [1 2]))
(秀 "(= @[1 2] @[1 2])  array" (= @[1 2] @[1 2]))
(秀 "(deep= @[1 2] @[1 2])" (deep= @[1 2] @[1 2]))
(print "  寫測試比較集合一律用 deep=（見 docs/23）")

(節 "所以只有不可變的能當字典的鍵")
(def k @{})
(put k [1 2] :用tuple)
(put k {:a 1} :用struct)
(put k @[1 2] :用array)
(秀 "用另一個等值 tuple 取" (get k [1 2]))
(秀 "用另一個等值 struct 取" (get k {:a 1}))
(秀 "用另一個等值 array 取" (get k @[1 2]))
(print "  ↑ array 取不到——它比的是「是不是同一個物件」。要複合鍵就 freeze（docs/35）")

(節 "⚠ 運算子不會幫你轉型")
(printf "  %-32s => %s" "(+ \"a\" \"b\")" (try (+ "a" "b") ([e] (string "報錯：" e))))
(print "    ↑ 訊息長得很奇怪，因為 + 對非數字會去找該型別的 :+ 方法")
(print "      認得這個訊息就等於認得這個坑")
(秀 "字串串接用 string" (string "共 " 3 " 個"))
(秀 "要分隔符用 string/join" (string/join @["a" "b"] ", "))
(秀 "(= \"1\" 1)  沒有隱式轉型" (= "1" 1))

(節 "方法呼叫語法：keyword 放在呼叫位置")
(def obj @{:greet (fn [self who] (string "hi " who))})
(秀 "(:greet obj \"you\")" (:greet obj "you"))
(print "  等於「拿出 :greet 那個函式，把 obj 自己當第一個參數傳進去」")
(print "\n  ⚠ 忘了寫 self 是最常見的錯：")
(def bad @{:inc (fn [n] (+ n 1))})
(printf "  %-32s => %s" "(:inc bad 5)  handler 只收一個參數"
        (try (:inc bad 5) ([e] (string "報錯：" e))))
(print "    ↑ 實際傳進去的是 (handler bad 5) 兩個參數")

(print "\n  ⚠ 更危險的一個：(:port cfg) 不是取值，而且靜默回 nil")
(def cfg {:port 4000})
(秀 "(cfg :port)      取值要這樣寫" (cfg :port))
(秀 "(get cfg :port)  或這樣" (get cfg :port))
(秀 "(:port cfg)      ← 不報錯，就是 nil" (:port cfg))
(print "    從 Clojure 過來的人會寫成後者——在那邊真的是取值，在 Janet 不是")
(print "    因果鏈（每一步都不報錯）：")
(秀 "  (:port cfg) 展開成 ((get cfg :port) cfg)" (get cfg :port))
(秀 "  也就是 (4000 cfg)，即 (get cfg 4000)" (get cfg 4000))
(print "    記法：(集合 鍵) 取值，(:鍵 物件) 呼叫方法")

(節 "巢狀存取")
(def 設定 @{:server @{:port 4000}})
(秀 "(get-in 設定 [:server :port])" (get-in 設定 [:server :port]))
(秀 "(get-in 設定 [:server :zz] 8080)" (get-in 設定 [:server :zz] 8080))
(put-in 設定 [:server :host] "127.0.0.1")
(秀 "(put-in 設定 [:server :host] …)" (設定 :server))
(秀 "(-?> 設定 (get :nope) (get :port))" (-?> 設定 (get :nope) (get :port)))
(print "    ↑ -?> 中途 nil 就短路，相當於別的語言的 ?.")

(節 "走訪")
(def 出 @[])
(each v arr (array/push 出 v))
(秀 "(each v arr …)" 出)
(def 出2 @[])
(eachp [k v] {:a 1} (array/push 出2 [k v]))
(秀 "(eachp [k v] t …)" 出2)
(秀 "(keys {:a 1 :b 2})" (keys {:a 1 :b 2}))
(秀 "(values {:a 1 :b 2})" (values {:a 1 :b 2}))
(print "  ⚠ 字典的走訪順序是 hash 順序，不是插入順序——別依賴它")

(print "\n✓ data-structures 跑完")
