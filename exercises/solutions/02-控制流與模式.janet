# 練習 02 的參考解答
#
#   janet exercises/solutions/02-控制流與模式.janet

# 1. ⚠ 只有 nil 和 false 是假——0、""、@[] 全是真（docs/32）。
#    所以「空的」要自己定義，不能靠 (if x …)。
#    ⚠ 還有一個：(empty? 0) 會爆，因為數字沒有長度（docs/38 的 lengthable?）。
(defn 空的? [x]
  (cond
    (nil? x) true
    (lengthable? x) (empty? x)
    false))

# 2. match 的常值 + 遞迴。(n (number? n)) 是「守衛」：先綁再檢查（docs/32）。
(defn 算 [e]
  (match e
    (n (number? n)) n
    [:+ a b] (+ (算 a) (算 b))
    [:* a b] (* (算 a) (算 b))
    (errorf "看不懂：%j" e)))

# 3. ⚠ (match v [a b c] true _ false) 是**錯的**——tuple 模式是前綴比對，
#    [1 2 3 4] 也會中。要「剛好 N 格」得自己檢查 length（docs/32）。
(defn 剛好三格? [v]
  (and (indexed? v) (= 3 (length v))))

# 4. get-in 的第三參數就是預設值，中間層是 nil 也不會炸（docs/20）。
#    另一種寫法：(or (-?> cfg (get :server) (get :port)) 8080)
(defn 取-port [cfg]
  (get-in cfg [:server :port] 8080))

# 5. ⚠ map / filter / reduce 的資料都在**最後**一個參數 → 用 ->>。
#    寫成 -> 的話 xs 會被塞到第一個參數，(filter xs odd?) 直接爆（docs/01c）。
(defn 奇數乘十加總 [xs]
  (->> xs
       (filter odd?)
       (map |(* $ 10))
       (reduce + 0)))

# 6. ⚠ :when 只是過濾、會繼續跑完；:while 條件一假就**中止**（docs/32b）。
#    這題要的是「遇到大於 100 就停」，所以是 :while。
(defn 小平方 [n]
  (seq [i :range [0 n]
        :when (zero? (mod i 3))
        :let [sq (* i i)]
        :while (<= sq 100)]
    sq))

# ── 檢查 ──────────────────────────────────────────────────────

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯) (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j" n 說明 預期 實得))))

(檢查 1 "判斷空的"
       (map 空的? ["" @[] @{} nil "a" @[1] 0])
       @[true true true true false false false])
(檢查 2 "迷你求值器" [(算 5) (算 [:+ 1 2]) (算 [:* [:+ 1 2] 10])] [5 3 30])
(檢查 3 "剛好三格" (map 剛好三格? [[1 2 3] [1 2] [1 2 3 4] "abc"])
       @[true false false false])
(檢查 4 "取 port"
       [(取-port {:server {:port 4000}}) (取-port {:server {}}) (取-port {})]
       [4000 8080 8080])
(檢查 5 "奇數乘十加總" (奇數乘十加總 [1 2 3 4 5]) 90)
(檢查 6 "小平方" (小平方 20) @[0 9 36 81])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(assert (zero? 錯) "參考解答自己沒過——那就是解答寫錯了")
(print "✓ 參考解答全部通過")
