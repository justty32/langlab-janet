# 序列工具 —— 配合 docs/25-序列工具.md
#
# 跑法：janet examples/seq-tools.janet
#
# 這支的重點是**看回傳型別**：Janet 的序列函式吃什麼都行，
# 但吐出來的東西是 array 還是 tuple、有沒有動到你的原資料，一定要親眼看過。

(defn 標題 [s] (print "\n─── " s " ───"))
(defn 秀 [expr v] (printf "  %-44s => %q" expr v))

# ── 規則一：進去什麼都吃，出來幾乎都是 array ──────────────────────────────
(標題 "規則一：輸出幾乎都是 array @[]")

(秀 "(map inc [1 2 3])        tuple 進" (map inc [1 2 3]))
(秀 "(map inc @[1 2 3])       array 進" (map inc @[1 2 3]))
(秀 "(map inc {:a 1 :b 2})    struct 進" (map inc {:a 1 :b 2}))
(print "  ↑ 字典走訪的是「值」，而且順序是雜湊順序、不是你寫的順序，不要依賴它。")
(print)
(print "  切割類是例外，它們回 tuple：")
(秀 "(type (take 2 @[1 2 3]))" (type (take 2 @[1 2 3])))
(秀 "(type (slice @[1 2 3] 1))" (type (slice @[1 2 3] 1)))
(秀 "(type (map inc @[1 2 3]))" (type (map inc @[1 2 3])))
(print "  要拿回不可變的 tuple 就自己包：")
(秀 "(tuple ;(map inc [1 2]))" (tuple ;(map inc [1 2])))

# ── 規則二：字串走訪出來是 byte 數字 ──────────────────────────────────────
(標題 "規則二：字串是位元組序列")

(秀 "(map |(* 2 $) \"abc\")" (map |(* 2 $) "abc"))
(秀 "(frequencies \"hello\")" (frequencies "hello"))
(printf "  ↑ 104 不是字元，是 byte：(string/from-bytes 104) => %q"
        (string/from-bytes 104))
(秀 "(frequencies [\"a\" \"a\" \"b\"])  陣列裡是字串就正常" (frequencies ["a" "a" "b"]))
(秀 "(length \"héllo\")  ← 不是 5" (length "héllo"))

# ── 規則三：原地改 vs 回新的 ──────────────────────────────────────────────
(標題 "規則三：sort 會改掉你的陣列")

(def a @[3 1 2])
(秀 "(sort a) 的回傳值" (sort a))
(秀 "  ...然後 a 自己變成" a)

(def b @[3 1 2])
(秀 "(sorted b) 的回傳值" (sorted b))
(秀 "  ...但 b 沒被動到" b)

(def c @[1 2 3])
(reverse! c)
(秀 "(reverse! c) 之後的 c" c)
(秀 "(reverse @[1 2 3]) 回新的" (reverse @[1 2 3]))

# ── 規則四：全部 eager，除了 generate ─────────────────────────────────────
(標題 "規則四：沒有惰性序列，除非用 generate")

(def g (generate [x :range [0 1000000]] (* x x)))
(秀 "(type (generate ...))" (type g))
(秀 "resume 三次（只算三個，不是一百萬個）"
    [(resume g) (resume g) (resume g)])
(秀 "推導：(seq [x :in [1 2 3 4] :when (even? x)] (* x 10))"
    (seq [x :in [1 2 3 4] :when (even? x)] (* x 10)))
(秀 "(loop ...) 的回傳值（不收集）" (loop [x :range [0 3]] x))

# ── 常見任務 ──────────────────────────────────────────────────────────────
(標題 "常見任務")

(def 資料 [5 3 8 3 1 8 8])
(秀 "原始資料" 資料)
(秀 "(distinct 資料)         去重" (distinct 資料))
(秀 "(frequencies 資料)      數次數" (frequencies 資料))
(秀 "(group-by even? 資料)   分組" (group-by even? 資料))
(秀 "(count even? 資料)      算幾個" (count even? 資料))
(秀 "(find even? 資料)       第一個符合的值" (find even? 資料))
(秀 "(find-index even? 資料) 第一個符合的位置" (find-index even? 資料))
(秀 "(keep |(if (even? $) (* $ 10)) 資料)  邊挑邊轉" (keep |(if (even? $) (* $ 10)) 資料))
(秀 "(accumulate + 0 [1 2 3 4])  看累加過程" (accumulate + 0 [1 2 3 4]))
(秀 "(reduce2 + [1 2 3 4])       不給初始值" (reduce2 + [1 2 3 4]))
# ⚠ 分隔符別寫 :| —— | 是 short-fn 的起手符，(interpose :| xs) 會解析成別的東西。
(秀 "(interpose :sep [1 2 3])    插分隔" (interpose :sep [1 2 3]))
(秀 "(interleave [1 2 3] [:a :b]) 交錯（最短為準）" (interleave [1 2 3] [:a :b]))
(秀 "(zipcoll [:a :b] [1 2])     配成 table" (zipcoll [:a :b] [1 2]))
(秀 "(flatten [1 [2 [3]]])       攤平" (flatten [1 [2 [3]]]))
(秀 "((juxt inc dec) 5)          一次套多個函式" ((juxt inc dec) 5))
(秀 "(map + [1 2 3] [10 20 30])  多序列併著走" (map + [1 2 3] [10 20 30]))
(秀 "(map + [1 2 3] [10 20])     長度以最短為準" (map + [1 2 3] [10 20]))

# ── partition 的兩個陷阱 ──────────────────────────────────────────────────
(標題 "⚠ partition 的兩個陷阱")

(def p (partition 2 [1 2 3 4 5]))
(秀 "(partition 2 [1 2 3 4 5])" p)
(printf "  ① 最後一塊只有 %d 個，不是 2 個" (length (last p)))
(printf "  ② 裡層型別是 %q" (type (first p)))
(def pb (partition-by even? [2 4 1 3 6]))
(秀 "(partition-by even? [2 4 1 3 6])" pb)
(printf "  ...但 partition-by 的裡層是 %q ← 兩個不一樣！" (type (first pb)))
(秀 "只要完整的塊：(filter |(= 2 (length $)) p)" (filter |(= 2 (length $)) p))

# ── 三個推導 ──────────────────────────────────────────────────────────────
(標題 "三個推導：seq / tabseq / catseq")

(秀 "(seq    [x :range [0 5] :when (odd? x)] (* x 10))"
    (seq [x :range [0 5] :when (odd? x)] (* x 10)))
(秀 "(tabseq [x :range [0 3]] x (* x x))" (tabseq [x :range [0 3]] x (* x x)))
(秀 "(catseq [x :range [0 3]] [x x])" (catseq [x :range [0 3]] [x x]))

(print "\n完。全部六十幾個函式的清單見 reference/序列與集合.md（共三份）。")
