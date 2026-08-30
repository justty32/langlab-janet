# 配合 docs/01c-解構與執行緒巨集.md
#
#   janet examples/threading.janet
#
# 解構的每種形狀，以及 -> 與 ->> 為什麼會給出不同答案。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-34s => %j" 說明 結果))

(節 "解構：把綁定位置寫成結構的形狀")
(def [a b & rest] [1 2 3 4])
(秀 "(def [a b & rest] [1 2 3 4])" [a b rest])
(def {:name n :age g} {:name "Al" :age 3})
(秀 "(def {:name n :age g} …)" [n g])
(def [p [r s]] [1 [2 3]])
(秀 "(def [p [r s]] [1 [2 3]])  巢狀" [p r s])
(def [m] @[7])
(秀 "array 也能解構" m)

(defn f [[a b] {:k k}] [a b k])
(秀 "函式參數位置直接拆 (f [1 2] {:k 9})" (f [1 2] {:k 9}))
(defn g2 [&keys {:host h :port p}] [h p])
(秀 "&keys 配解構 (g2 :host \"x\" :port 80)" (g2 :host "x" :port 80))
(def 出 @[])
(each [k v] (pairs {:a 1 :b 2}) (array/push 出 [k v]))
(秀 "each 走 pairs" 出)
(print "  會少寫非常多 (x 0) (x 1) 這種索引")

(節 "⚠ 靜默處①：值不夠時補 nil，不報錯")
(def [x y z] [1 2])
(秀 "(def [x y z] [1 2])  z 是什麼" [x y z])
(def {:zz q} {:a 1})
(秀 "(def {:zz q} {:a 1})  q 是什麼" q)
(print "  所以解構不能當成「檢查形狀對不對」的手段——要檢查就自己 assert")

(節 "⚠ 靜默處②：解構字串拿到的是 byte 數字")
(def [c1 c2] "ab")
(秀 "(def [c1 c2] \"ab\")" [c1 c2])
(秀 "轉回字元要自己來" [(string/from-bytes c1) (string/from-bytes c2)])
(print "  跟 docs/18、docs/25 是同一條規則：字串的元素是 byte")

(節 "執行緒巨集：把巢狀攤平")
(秀 "(-> 5 (+ 3) (* 2))" (-> 5 (+ 3) (* 2)))
(秀 "  它展開成" (macex1 '(-> 5 (+ 3) (* 2))))
(秀 "(->> [1 2 3] (map inc) (filter even?))" (->> [1 2 3] (map inc) (filter even?)))
(秀 "  它展開成" (macex1 '(->> [1 2 3] (map inc))))
(秀 "-> 也吃裸 symbol (-> 5 inc inc)" (-> 5 inc inc))

(節 "★ 選錯會安靜地算出別的答案")
(秀 "(-> 2 (- 10))   2 塞第一個 → (- 2 10)" (-> 2 (- 10)))
(秀 "(->> 2 (- 10))  2 塞最後   → (- 10 2)" (->> 2 (- 10)))
(print "  同一串符號、兩個答案，而且都不會報錯")
(print "  ⚠ 參數順序有意義的運算（減、除、get、string/find）一定要想清楚塞哪")
(print "  不確定就 macex1 看展開——上面每一條都示範了")

(節 "不吃預設位置時用 as->，$ 放哪就塞哪")
(秀 "(as-> 2 $ (- 10 $) (* $ 3))" (as-> 2 $ (- 10 $) (* $ 3)))
(秀 "(as-> 5 $ (+ $ 1) (* $ $))" (as-> 5 $ (+ $ 1) (* $ $)))

(節 "-?> 與 -?>>：中途 nil 就短路")
(秀 "(-?> {:a {:b 7}} (get :a) (get :b))" (-?> {:a {:b 7}} (get :a) (get :b)))
(秀 "(-?> {:a nil} (get :a) (get :b))" (-?> {:a nil} (get :a) (get :b)))
(秀 "(-?>> nil (map inc))" (-?>> nil (map inc)))
(print "  相當於別的語言的 ?. ——中途拿到 nil 就不再往下呼叫，不會炸")

(節 "慣例")
(print "  資料處理鏈（map / filter 這種資料在最後的）→ ->>")
(print "  物件式的（資料在最前的，像 get / put / :method）→ ->")

(print "\n✓ threading 跑完")
