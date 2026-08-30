# 配合 docs/34-讀錯誤訊息.md
#
#   janet examples/error-anatomy.janet
#
# 把各種錯誤「安全地」製造出來看清楚長相：
#   - parse / compile 錯誤用 (parse-all) 與 (compile) 隔離，不會炸掉本檔
#   - runtime 錯誤用 try 接住
# 所以這支檔會一路跑完並 exit 0。

(defn 節 [t] (print "\n── " t " ─────────────────────"))

(節 "三類錯誤，第一行就分得出來")

# parse error：檔案根本讀不完
(def p (try (parse "(print (+ 1 2)") ([e] e)))
(printf "  parse   → %s" p)

# compile error：讀完了但編不成
(defn 兩參數 [x y] [x y])
(def c1 (compile '(未定義的東西 1) (curenv)))
(def c2 (compile '(兩參數 1) (curenv)))
(printf "  compile → %s" (c1 :error))
(printf "  compile → %s" (c2 :error))

# runtime error：跑起來才炸，而且有堆疊
(printf "  runtime → %s" (try (error "壞了") ([e] e)))
(print "  ⚠ 前兩類 try 攔不到——它們發生在「開始跑」之前")

(節 "堆疊由內往外，in thunk 是檔案頂層")
(defn 第三層 [x] (error "最裡面炸了"))
(defn 第二層 [x] (+ 1 (第三層 x)))
(defn 第一層 [x] (第二層 x))
(print "  ⚠ 堆疊走 stderr，所以它多半印在這支檔的最上面而不是這裡——")
(print "     這正是文件講的「兩條管線各自緩衝、順序會錯亂」。要對齊就 2>&1 導在一起。")
(try (第一層 42) ([e f] (debug/stacktrace f e "")))
(print "  ⚠ 看不到「第一層」——它的呼叫在尾位置，frame 被換掉了")
(print "  行尾的 (tail call) 就是線索：那一格自己做了尾呼叫，跟下一格之間可能藏了層")

(節 "資料結構本身可呼叫 = 索引自己")
(printf "  (\"abc\" 1)   => %j   等同 (get \"abc\" 1)" ("abc" 1))
(printf "  ({:a 9} :a) => %j   等同 (get {:a 9} :a)" ({:a 9} :a))

(節 "⚠ 所以「呼叫 nil」的訊息會在講參數的型別")
(def f nil)
(printf "  (f 1)   → %s" (try (apply f [1]) ([e] e)))
(print "    ↑ 它被當成 (get 1 nil)，抱怨的是「1 不能被索引」，完全沒提 nil")
(printf "  (f)     → %s" (try (apply f []) ([e] e)))
(printf "  (f 1 2) → %s" (try (apply f [1 2]) ([e] e)))
(print "    ↑ 零個或兩個以上參數就沒有歧義，訊息才變好懂")
(print "  記法：訊息在講一個你沒預期的型別 → 先確認你呼叫的東西是不是 nil")

(節 "常見錯誤訊息各長什麼樣")
(each [說明 f] [["數字加字串"     (fn [] (+ 1 "a"))]
                ["索引超出範圍"   (fn [] ([1 2] 9))]
                ["keyword 當方法" (fn [] (:a 5))]
                ["找不到模組"     (fn [] (require "./絕對不存在"))]]
  (printf "  %-14s → %s" 說明 (try (f) ([e] (string e)))))

(節 "trace：不改程式碼看某個函式被怎麼呼叫")
(defn g [x] (* x 2))
(trace g)
(printf "  (g 5) => %j" (g 5))
(printf "  (g 7) => %j" (g 7))
(untrace g)
(printf "  untrace 之後 (g 6) => %j（不再印 trace 行）" (g 6))

(print "\n✓ error-anatomy 跑完")
