# 配合 docs/01-語言速成.md
#
#   janet examples/quickstart.janet
#
# 第一支範例：括號家族、綁定、函式、條件、迴圈，一路跑完。
# 每一段都印出真實結果——包括那個「print 印陣列會給你位址」的地雷。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-32s => %j" 說明 結果))

(節 "括號家族：() 是呼叫，[] 與 {} 是資料")
(秀 "(+ 1 2)          () 當函式呼叫" (+ 1 2))
(秀 "[1 2 3]          tuple" [1 2 3])
(秀 "[(+ 1 1) (* 2 3)] 裡面照樣求值" [(+ 1 1) (* 2 3)])
(秀 "{:a 1 :b 2}      struct" {:a 1 :b 2})
(秀 "{:a (+ 40 2)}    值也求值" {:a (+ 40 2)})
(print "  ↑ 所以「長得像 JSON 的東西」在 Janet 就是合法字面資料，還能內含計算")

(節 "前綴 @ ＝ 可變版")
(each [寫法 v] [["[1 2 3]" [1 2 3]] ["@[1 2 3]" @[1 2 3]]
                ["{:a 1}" {:a 1}]   ["@{:a 1}" @{:a 1}]]
  (printf "  %-10s type=%-8j 可變？%s" 寫法 (type v)
          (if (or (array? v) (table? v)) "✓" "✗")))

(節 "綁定：def / var / let")
(def x 10)
(var y 20)
(set y 30)
(秀 "(def x 10)  不可變" x)
(秀 "(var y 20) 再 (set y 30)" y)
(秀 "(let [a 1 b 2] (+ a b))  區域" (let [a 1 b 2] (+ a b)))
(printf "  %-32s => %s" "改 def 綁的東西會怎樣"
        (let [r (compile '(do (def z 1) (set z 2)) (curenv))]
          (if (table? r) (string "compile error: " (r :error)) "（居然過了）")))
(print "  慣例：優先 def，真的要改才 var")

(節 "函式")
(defn 加 [a b] (+ a b))
(秀 "(defn 加 [a b] …) 再 (加 3 4)" (加 3 4))
(秀 "匿名函式 ((fn [n] (* n n)) 5)" ((fn [n] (* n n)) 5))
(秀 "短寫法 (map |(* $ $) [1 2 3])" (map |(* $ $) [1 2 3]))
(print "  參數的五種形式（&opt / & rest / &named / &keys）見 docs/33")

(節 "條件")
(秀 "(if (> 3 2) :大 :小)" (if (> 3 2) :大 :小))
(秀 "(when true :跑了)" (when true :跑了))
(秀 "(cond (< 5 0) :負 (zero? 5) :零 :正)" (cond (< 5 0) :負 (zero? 5) :零 :正))
(print "  ⚠ 只有 nil 和 false 是假——0 和空字串都是真（見 docs/32）：")
(秀 "  (if 0 :真 :假)" (if 0 :真 :假))

(節 "迴圈與序列")
(def 收 @[])
(each v [1 2 3] (array/push 收 (* v 10)))
(秀 "(each v [1 2 3] …)" 收)
(秀 "(seq [i :range [0 4]] (* i i))" (seq [i :range [0 4]] (* i i)))
(秀 "(map inc [1 2 3])" (map inc [1 2 3]))
(秀 "(filter even? [1 2 3 4])" (filter even? [1 2 3 4]))
(秀 "(reduce + 0 [1 2 3 4])" (reduce + 0 [1 2 3 4]))
(print "  loop 的完整 verb 表見 docs/32b")

(節 "★ 重要地雷：print 印陣列給你的是位址")
(prin "  (print @[1 2 3])   => ") (print @[1 2 3])
(prin "  (pp @[1 2 3])      => ") (pp @[1 2 3])
(printf "  (printf \"%%q\" …)     => %q" @[1 2 3])
(printf "  (printf \"%%p\" …)     => %p" @[1 2 3])
(print "  ↑ 要看內容用 pp 或 %q／%p，別用 print")
(printf "  %-32s => %j" "⚠ %j 是單行 Janet 表示法，不是 JSON" (string/format "%j" {:a 1}))
(print "    要印真 JSON 只有一條路：(json/encode x)，見 docs/03")

(節 "⚠ 中文在 %j／%q 下會被逃逸")
(printf "  %-20s => %j" "%j 印中文" "你好")
(printf "  %-20s => %s" "%s 印中文" "你好")
(print "  ↑ 這不是壞掉：%j／%q 要保證印出來的東西能被 parse 回去，所以逃逸非 ASCII")
(print "    給人看的輸出一律用 %s")

(節 "註解是 #，不是 ;")
(print "  # 井號到行尾是註解")
(print "  ⚠ ; 在 Janet 是 splice 運算子——寫成註解會編譯錯（見 docs/08）")

(print "\n✓ quickstart 跑完——下一篇 docs/01b 是給 C++ 開發者的概念對照")
