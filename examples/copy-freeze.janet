# 配合 docs/35-拷貝與凍結.md 與 docs/35b-走訪與改寫巢狀資料.md
#
#   janet examples/copy-freeze.janet
#
# ⚠ 有兩件事這支檔「刻意不真的跑」，因為它們會卡死而不是報錯：
#     (freeze 有循環參照的東西)   → 無限遞迴
#     prewalk 的函式製造出新的可比對節點 → 無限重入
#   下面用加了計數器的安全版本示範第二件，第一件只描述。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-30s => %j" 說明 結果))

(節 "def 只是換個名字，沒有拷貝")
(def a @[1 2])
(def b a)
(array/push b 3)
(秀 "改 b 之後 a" a)

(節 "⚠ table/clone 與 array/slice 都是淺的")
(def 原 @{:a @[1 2]})
(def 淺 (table/clone 原))
(array/push (原 :a) 99)
(秀 "改 原 的內層，淺拷貝的 :a" (淺 :a))
(print "  外層是新的（塞新鍵不互相影響），但 :a 底下是同一個 array")

(def a2 @[@[1] 2])
(def s2 (array/slice a2))
(array/push (get a2 0) 9)
(秀 "array/slice 的內層" (get s2 0))

(節 "freeze：深度轉不可變，順便換型別")
(def 凍 (freeze @{:a @[1 2] :b @"x"}))
(秀 "外層型別" (type 凍))
(秀 ":a 的型別" (type (凍 :a)))
(秀 ":b 的型別（buffer → ？）" (type (凍 :b)))
(秀 "已經不可變的丟進去" (type (freeze {:a 1})))
(秀 "函式原樣留著" (type (get (freeze @{:f (fn [] 1)}) :f)))

(節 "thaw：解凍也是深的 → 深拷貝 = thaw ∘ freeze")
(def 原2 @{:a @[1 2]})
(def 深1 (thaw (freeze 原2)))
(def 深2 (unmarshal (marshal 原2)))
(array/push (原2 :a) 9)
(秀 "thaw∘freeze 的 :a" (深1 :a))
(秀 "unmarshal∘marshal 的 :a" (深2 :a))
(秀 "原2 的 :a（只有它變了）" (原2 :a))
(print "  ⚠ 但循環參照只有 marshal 撐得住：")
(print "     (def c @{}) (put c :self c) (freeze c) → 不報錯，直接卡死")

(節 "為什麼要凍：array 當不了字典的鍵，tuple 可以")
(def t @{})
(put t @[1 2] :用array)
(put t [1 2] :用tuple)
(秀 "(get t @[1 2]) ← 另一個等值 array" (get t @[1 2]))
(秀 "(get t [1 2])  ← 另一個等值 tuple" (get t [1 2]))
(print "  array 比身分所以取不到；tuple 比內容所以取得到。要複合鍵就先 freeze")

(節 "walk 只走一層")
(秀 "(walk 加倍 [1 [2 3]])" (walk |(if (number? $) (* 2 $) $) [1 [2 3]]))
(print "  裡面的 2 3 沒變——[2 3] 整個被當成一個子元素傳進去")

(節 "postwalk / prewalk 的拜訪順序")
(defn 記錄器 []
  (def 序 @[])
  [序 (fn [n] (array/push 序 (if (indexed? n) (string "節點" (string/format "%j" n)) n)) n)])
(def [s1 g1] (記錄器)) (prewalk  g1 [1 [2 3]])
(def [s2 g2] (記錄器)) (postwalk g2 [1 [2 3]])
(printf "  prewalk （由外往內）%s" (string/join (map string s1) " → "))
(printf "  postwalk（由內往外）%s" (string/join (map string s2) " → "))

(節 "⚠ prewalk 會走進自己換出來的東西（這就是無限遞迴的來源）")
(var 次數 0)
(defn 展開 [n]
  (if (and (indexed? n) (= :x (get n 0)) (< 次數 3))
    (do (++ 次數) [:y [:x]])      # 換出一個新的 [:x]
    n))
(set 次數 0)
(def pre-結果 (prewalk 展開 [:x]))
(printf "  prewalk  換了 %d 次 → %j" 次數 pre-結果)
(set 次數 0)
(def post-結果 (postwalk 展開 [:x]))
(printf "  postwalk 換了 %d 次 → %j" 次數 post-結果)
(print "  prewalk 一直走進換出來的 [:x]，這裡是計數器擋住才停；沒擋就是卡死")
(print "  postwalk 處理完子節點才輪到父節點，不會回頭 → 不確定用哪個就用它")

(節 "next：底層迭代協定")
(def d {:p 1 :q 2})
(var k (next d nil))
(while k
  (printf "  %j → %j" k (d k))
  (set k (next d k)))
(秀 "走到底回" (next d (next d (next d nil))))

(節 "字典日常操作")
(秀 "(merge {:a 1} {:b 2} {:a 9})" (merge {:a 1} {:b 2} {:a 9}))
(秀 "merge 的回傳型別" (type (merge {:a 1} {:b 2})))
(秀 "(invert {:a 1 :b 2})" (invert {:a 1 :b 2}))
(秀 "(update @{:n 1} :n inc)" (update @{:n 1} :n inc))
(秀 "(get-in {:a {}} [:a :zz] :預設)" (get-in {:a {}} [:a :zz] :預設))
(秀 "(put-in @{:a @{}} [:a :b] 5)" (put-in @{:a @{}} [:a :b] 5))
(print "  ⚠ merge 一律回 table，即使餵進去的全是 struct")

(節 "實際場景：把每一層字串裡的 ${HOME} 展開")
(def 設定 {:home "${HOME}/x" :list ["${HOME}/y" 3] :深 {:更深 "${HOME}/z"}})
(秀 "postwalk 一行搞定"
    (postwalk (fn [x] (if (string? x) (string/replace-all "${HOME}" "/home/me" x) x)) 設定))

(print "\n✓ copy-freeze 跑完")
