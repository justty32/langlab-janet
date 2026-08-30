# 配合 docs/32b-loop-全表.md
#
#   janet examples/loop-tour.janet
#
# loop 的 verb 與條件詞各跑一遍，把結果印出來對照。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-30s => %j" 說明 結果))

(節 "八個 verb：決定走什麼")
(秀 "[i :range [0 3]]"      (seq [i :range [0 3]] i))
(秀 "[i :range [0 7 2]]"    (seq [i :range [0 7 2]] i))
(秀 "[i :range-to [0 3]]"   (seq [i :range-to [0 3]] i))
(秀 "[i :down [3 0]]"       (seq [i :down [3 0]] i))
(秀 "[i :down-to [3 0]]"    (seq [i :down-to [3 0]] i))
(秀 "[i :down [6 0 2]]"     (seq [i :down [6 0 2]] i))
(秀 "[x :in {:p 1 :q 2}]"   (seq [x :in {:p 1 :q 2}] x))
(秀 "[k :keys {:p 1 :q 2}]" (seq [k :keys {:p 1 :q 2}] k))
(秀 "[k :keys [10 20 30]]"  (seq [k :keys [10 20 30]] k))
(秀 "[[k v] :pairs {:p 1}]" (seq [[k v] :pairs {:p 1}] [k v]))
(秀 "[c :in \"ab\"]"          (seq [c :in "ab"] c))
(print "  ↑ 走字串拿到的是 byte 數字（97 98），不是字元")

# :iterate —— 反覆求值直到假值，拿來包「還有下一個嗎」這種 API
(var 剩 3)
(秀 "[x :iterate 倒數到 0]"
    (seq [x :iterate (do (-- 剩) (if (pos? 剩) 剩))] x))

(節 "⚠ :range 的負步長靜默給空的")
(秀 "(seq [i :range [3 0 -1]] i)" (seq [i :range [3 0 -1]] i))
(秀 "(range 3 0 -1)  ← 函式版"    (range 3 0 -1))
(print "  同一個名字兩套規矩：loop 的 :range 步長必須是正的，給負的不報錯只是不跑")
(print "  要倒著走一律用 :down / :down-to")

(節 "八個條件詞：決定怎麼走")
(秀 ":when (even? i)"   (seq [i :range [0 6] :when (even? i)] i))
(秀 ":unless (even? i)" (seq [i :range [0 6] :unless (even? i)] i))
(秀 ":while (< i 3)"    (seq [i :range [0 9] :while (< i 3)] i))
(秀 ":until (> i 2)"    (seq [i :range [0 9] :until (> i 2)] i))
(秀 ":let [sq (* i i)]" (seq [i :range [0 3] :let [sq (* i i)]] sq))

(def 計 @[])
(loop [:repeat 3] (array/push 計 :x))
(秀 ":repeat 3" 計)

(節 "⚠ :before / :after 是每圈都跑")
(def a @[])
(loop [i :range [0 2] :before (array/push a :前) :after (array/push a :後)]
  (array/push a i))
(秀 "before/after 的實際順序" a)
(print "  不是 @[:前 0 1 :後]——它是每一輪內圈的前後，不是整個迴圈的頭尾")

(節 "多層：條件詞只作用在它前面那一層")
(秀 ":when 放中間" (seq [i :range [0 3] :when (odd? i) j :range [0 2]] [i j]))
(秀 ":when 放最後" (seq [i :range [0 3] j :range [0 2] :when (odd? i)] [i j]))
(print "  結果一樣，但放中間時 i 是偶數就連內層 j 迴圈都不開——位置決定效率")

(節 "loop 回傳 nil，要結果就換推導")
(秀 "(loop [i :range [0 3]] i)"    (loop [i :range [0 3]] i))
(秀 "(seq [i :range [0 3]] i)"     (seq [i :range [0 3]] i))
(秀 "(tabseq [i :range [1 3]] …)"  (tabseq [i :range [1 3]] i (* i i)))
(秀 "(catseq [i :range [1 3]] …)"  (catseq [i :range [1 3]] [i i]))

(節 "單純走一圈時，短形式比 loop 好讀")
(def b @[])
(each x [10 20] (array/push b x))
(秀 "(each x [10 20] …)" b)
(def c @[])
(for i 0 3 (array/push c i))
(秀 "(for i 0 3 …)" c)
(def d @[])
(loop [i :range [0 9]] (if (= i 3) (break)) (array/push d i))
(秀 "loop 裡的 (break)" d)

(print "\n✓ loop-tour 跑完")
