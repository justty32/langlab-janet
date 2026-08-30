# 配合 docs/32-條件與模式比對.md
#
#   janet examples/match-demo.janet
#
# 每一段都印出「實際結果」，跟教學裡寫的對照著看。

(defn 節 [t] (print "\n── " t " ─────────────────────"))

(節 "只有 nil 和 false 是假")
(each v [0 "" @[] nil false]
  (printf "  %-6s → %s" (string/format "%j" v) (if v "真" "假")))
(print "  ⚠ 0 和空字串在 Janet 是真，跟 C/C++ 相反")

(節 "and / or 回傳的是值本身，不是 true/false")
(printf "  (and 1 2 3)      => %j" (and 1 2 3))
(printf "  (and 1 false 3)  => %j" (and 1 false 3))
(printf "  (or nil false 7) => %j" (or nil false 7))

(節 "case 用 = 比：tuple 中、array 不中")
(printf "  (case [1 2]  [1 2]  …) => %j" (case [1 2] [1 2] :中了 :沒中))
(printf "  (case @[1 2] @[1 2] …) => %j" (case @[1 2] @[1 2] :中了 :沒中))
(print "  tuple 不可變所以比內容；array 可變所以比身分")

(節 "match：比形狀，順便綁內容")
# 一個迷你運算式求值器——match 最典型的用法
(defn 算 [e]
  (match e
    (n (number? n))  n
    [:+ a b]         (+ (算 a) (算 b))
    [:* a b]         (* (算 a) (算 b))
    [:neg a]         (- (算 a))
    _                (errorf "看不懂的運算式：%j" e)))

(each e [[:+ 1 2]
         [:* [:+ 1 2] 10]
         [:neg [:* 3 4]]]
  (printf "  %-22s => %j" (string/format "%j" e) (算 e)))

(def [ok 訊息] (protect (算 [:mod 1 2])))
(printf "  沒中的分支 → %s：%s" (if ok "成功" "報錯") 訊息)

(節 "字典模式是子集比對")
(defn 打招呼 [u]
  (match u
    {:name n :vip true} (string "貴賓 " n "，您好")
    {:name n}           (string "哈囉 " n)
    _                   "你是誰"))
(each u [{:name "Alice" :vip true :age 30}
         {:name "Bob" :age 20}
         {:age 5}]
  (printf "  %-34s => %s" (string/format "%j" u) (打招呼 u)))
(print "  ⚠ 多出來的鍵（:age）不影響比對")

(節 "同一個名字出現兩次 = 要求相等")
(each v [[1 1] [1 2]]
  (printf "  %j → %j" v (match v [a a] :兩格相同 _ :不同)))

(節 "⚠ 最大的坑：tuple 模式是前綴比對")
(printf "  (match [1 2 3] [a b] :兩格 [a b c] :三格) => %j"
        (match [1 2 3] [a b] :兩格 [a b c] :三格))
(print "  ↑ 拿到 :兩格 不是 :三格——短模式排前面會遮住長的，而且不報錯")
(printf "  模式排長到短就對了                        => %j"
        (match [1 2 3] [a b c] :三格 [a b] :兩格))
(printf "  真要「剛好兩格」用守衛                    => %j"
        (match [1 2 3] (t (and (indexed? t) (= 2 (length t)))) :剛好兩格 _ :不是兩格))

(節 "when-let：綁不到就整個放棄，後面完全不求值")
(printf "  拿得到 → %j" (when-let [p (get {:port 4000} :port)] (* p 2)))
(printf "  拿不到 → %j" (when-let [p (get {} :port)] (* p 2)))
(printf "  中途 nil，後面的 (error …) 沒被跑到 → %j"
        (when-let [a 1 b nil c (error "這行不會跑")] [a b c]))

(節 "沒中又沒有 _ 時回 nil，不會報錯")
(printf "  (match 5 0 \"零\") => %j" (match 5 0 "零"))
(print "  ⚠ 漏寫分支會變成靜默的 nil，不是錯誤——這是 match 最常見的 bug 來源")

(print "\n✓ match-demo 跑完")
