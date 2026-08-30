# 配合 docs/36-排序與比較.md
#
#   janet examples/sorting.janet

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-34s => %j" 說明 結果))

(節 "四個函式：過去式給你新的，原形原地改")
(def a @[3 1 2])
(秀 "(sorted a)" (sorted a))
(秀 "  a 有沒有變" a)
(秀 "(sort a)" (sort a))
(秀 "  a 現在" a)
(秀 "sort 回的是不是 a 本身" (let [b @[3 1 2]] (= b (sort b))))
(print "  ⚠ sort 沒有驚嘆號卻是原地改——25 那條「驚嘆號＝原地改」在這裡是例外")

(節 "比較器是「小於」，兩個參數回真假")
(秀 "(sorted @[3 1 2] <)" (sorted @[3 1 2] <))
(秀 "(sorted @[3 1 2] >)" (sorted @[3 1 2] >))

(節 "⚠ 拿 compare 當比較器：算出垃圾，錯誤訊息還在講別的")
(秀 "(compare 1 2) (compare 2 2) (compare 3 2)" [(compare 1 2) (compare 2 2) (compare 3 2)])
(printf "  (sorted @[3 1 2] compare) → %s" (try (sorted @[3 1 2] compare) ([e] (string e))))
(printf "  為什麼：(if 0 :真 :假) = %j —— 0 在 Janet 是真" (if 0 :真 :假))
(print "  所以 -1 / 0 / 1 三個都是真，排序認為「永遠 a 在前」，一路走出邊界")
(秀 "改用 compare< 就對了" (sorted @[3 1 2] compare<))

(節 "多鍵排序：sorted-by ＋ tuple key（tuple 是逐格比的）")
(秀 "(< [1 2] [1 3])" (< [1 2] [1 3]))
(秀 "(< [1] [1 0])   短的排前面" (< [1] [1 0]))

(def 人 @[{:n "a" :age 30} {:n "b" :age 20} {:n "c" :age 30} {:n "d" :age 20}])
(秀 "先 age 再 n（tuple key）" (map |($ :n) (sorted-by |[($ :age) ($ :n)] 人)))

(defn 先age再n [x y]
  (if (= (x :age) (y :age)) (< (x :n) (y :n)) (< (x :age) (y :age))))
(秀 "同一件事用自訂比較器" (map |($ :n) (sorted 人 先age再n)))
(print "  ⚠ sorted-by 每次比較都重算 key——key 算起來貴就先算好存起來")

(節 "⚠ Janet 的排序不穩定")
(def xs (seq [i :range [0 8]] {:i i :k (mod i 2)}))
(秀 "原始的 :i 順序" (map |($ :i) xs))
(秀 "依 :k 排序後" (map |($ :i) (sorted-by |($ :k) xs)))
(print "  k=0 那組原本是 0 2 4 6，排完卻不是——同鍵的相對順序沒有保證")
(print "  C++ 有 std::stable_sort，Janet 沒有對應物")
(秀 "把原始索引放進 key 最後一格" (map |($ :i) (sorted-by |[($ :k) ($ :i)] xs)))
(print "  ↑ 這樣結果就完全可預測了")

(節 "跨型別排序不報錯，但別依賴那個順序")
(def 混 (sorted @[{} @[] :k "s" true nil 1 [] @""]))
(秀 "sorted 混型別" 混)
(秀 "各是什麼型別" (map type 混))
(print "  這個順序沒寫進語言規格，只是實作細節——要排混型別就自己給比較器")

(節 "字串是逐 byte 比（ASCII），大寫在小寫前")
(秀 "(sorted @[\"b\" \"A\" \"a\"])" (sorted @["b" "A" "a"]))
(秀 "不分大小寫" (sorted-by string/ascii-lower @["b" "A" "a"]))
(def 中文 (sorted @["張" "李" "王"]))
(printf "  %-34s => %s" "中文比的是 UTF-8 byte" (string/join 中文 " "))
(printf "  %-34s => %j" "  它們的第一個 byte" (map |(get $ 0) 中文))
(print "  ↑ 不是筆畫也不是注音，就是 byte 大小（229 < 230 < 231）")

(print "\n✓ sorting 跑完")
