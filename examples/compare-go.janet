# 配合 docs/45、45b（從 Go 過來的逐條對照）
#
#   janet examples/compare-go.janet
#
# 每列印「Go 的寫法 → Janet 的寫法 → 實際結果」。Go 那欄只是註解，不會真的跑。
# 後半的 ev 部分每段都會在幾十毫秒內結束，整支跑完 exit 0。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 顯示 [r] (if (string? r) (string "\"" r "\"") (string/format "%j" r)))   # 字串直接印，%j 會把中文逃逸
(defn 列 [go j r] (printf "  %-32s %-36s => %s" go j (顯示 r)))
(defn 錯 [f] (try (do (f) :沒報錯) ([e] (string "錯：" e))))

(節 "err 慣例")
(defn parse-int [s] (if-let [n (scan-number s)] [n nil] [nil (string "not a number: " s)]))
(列 "n, err := parse-int(\"12\")" "(def [n err] (parse-int \"12\"))" (parse-int "12"))
(列 "n, err := parse-int(\"x\")" "同上" (parse-int "x"))
(列 "val, err := f()  （f 會 panic）" "(protect (error \"boom\"))" (protect (error "boom")))
(列 "errors.Is(err, NotFound)" "(match e {:code 404} …)"
    (try (error {:code 404}) ([e] (match e {:code 404} :not-found _ :other))))
(列 "fmt.Errorf(\"outer: %w\", err)" "(error {:msg \"outer\" :cause e})"
    (try (try (error "inner") ([e] (error {:msg "outer" :cause e}))) ([e] [(e :msg) (e :cause)])))

(節 "defer：收尾寫前面、巢狀是 LIFO")
(def log @[])
(defer (array/push log :third) (defer (array/push log :second) (array/push log :first)))
(列 "defer A; defer B; body" "(defer A (defer B body))" log)

(節 "slice 是拷貝、def 是共用")
(def a @[1 2 3 4])
(def s (array/slice a 1 3))
(put s 0 :changed)
(列 "s := a[1:3]; s[0] = x  （a 也變）" "(array/slice a 1 3)  ⚠ a 不變" [a s])
(def b a) (array/push b 5)
(列 "b := a  （共用）" "(def b a)  一樣共用" a)
(列 "make([]int, 3)" "(array/new-filled 3 0)" (array/new-filled 3 0))
(列 "⚠ 不是這個" "(length (array/new 3))  只是 cap" (length (array/new 3)))

(節 "map")
(def m @{:a 1})
(列 "m[\"b\"]  零值" "(get m :b)" (get m :b))
(列 "v, ok := m[\"b\"]" "(has-key? m :b)" (has-key? m :b))
(列 "delete(m, \"a\")" "(put m :a nil)" (put m :a nil))
(列 "m == nil 時寫入 panic" "(put nil :a 1)" (錯 |(put nil :a 1)))

(節 "struct、method、interface")
(def Dog @{:speak (fn [self] (string (self :name) ": woof"))})
(def Cat @{:speak (fn [self] "meow")})
(defn new-dog [n] (table/setproto @{:name n} Dog))
(列 "d.Speak()" "(:speak d)" (:speak (new-dog "rex")))
(列 "[]Speaker{dog, cat}" "有 :speak 就能叫，不用宣告 interface"
    (map |(:speak $) [(new-dog "a") (table/setproto @{} Cat)]))
(列 "沒實作 interface：編譯錯" "(:speak @{})  執行時才錯" (錯 |(:speak @{})))

(節 "fmt 動詞")
(列 "%d %s %.2f %x" "同名" (string/format "%d %s %.2f %x" 42 "s" 3.14159 255))
(列 "%v" "%j / %p" [(string/format "%j" {:a [1]}) (string/format "%p" @[1])])
(列 "%t  （bool）" "(string/format \"%t\" true)  ⚠ 印型別" (string/format "%t" true))
(列 "%T  （型別）" "%t 才是這個" (string/format "%t" @[]))

(節 "for range")
(def r @[])
(eachp [i v] [:a :b] (array/push r [i v]))
(列 "for i, v := range xs" "(eachp [i v] xs …)" r)
(def bs @[]) (each c "hé" (array/push bs c))
(列 "for _, r := range \"hé\"  （rune）" "(each c \"hé\" …)  ⚠ byte" bs)
(列 "for i := range 3" "(seq [i :range [0 3]] i)" (seq [i :range [0 3]] i))

(節 "goroutine：單執行緒，沒有讓出點就不交錯")
(def log1 @[])
(ev/go (fn [] (for i 0 3 (array/push log1 [:a i]))))
(ev/go (fn [] (for i 0 3 (array/push log1 [:b i]))))
(ev/sleep 0)
(列 "go f(); go g()  （交錯）" "(ev/go f) (ev/go g)  沒 sleep" log1)
(def log2 @[])
(ev/go (fn [] (for i 0 3 (array/push log2 [:a i]) (ev/sleep 0))))
(ev/go (fn [] (for i 0 3 (array/push log2 [:b i]) (ev/sleep 0))))
(ev/sleep 0.01)
(列 "同上" "圈內加 (ev/sleep 0) 才交錯" log2)
(flush)
(def bad (ev/go (fn [] (error "goroutine boom"))))
(ev/sleep 0.005)
(列 "panic 在 goroutine：整個程式死" "(ev/go …) 裡 error：只印到 stderr" (fiber/status bad))

(節 "channel：close+range 要改寫")
(def ch (ev/chan 2))
(ev/go (fn [] (for i 0 3 (ev/give ch i)) (ev/chan-close ch)))
(def lost @[])
(while (def v (ev/take ch)) (array/push lost v))
(列 "close(ch); for v := range ch" "chan-close 後緩衝區讀不到  ⚠" lost)
(def ch2 (ev/chan 2))
(ev/go (fn [] (for i 0 3 (ev/give ch2 i)) (ev/give ch2 :done)))
(def got @[])
(while (not= :done (def v (ev/take ch2))) (array/push got v))
(列 "同上" "改送哨兵值 :done" got)

(節 "select、逾時、WaitGroup、context")
(def fast (ev/chan)) (def slow (ev/chan 1))   # slow 給緩衝，否則沒人收它就結束不了
(ev/go (fn [] (ev/sleep 0.02) (ev/give slow :slow)))
(ev/go (fn [] (ev/give fast :fast)))
(def [op which v] (ev/select fast slow))
(列 "select { case <-fast: case <-slow: }" "(ev/select fast slow)" [op (= which fast) v])
(def never (ev/chan))
(列 "case <-time.After(10ms)" "(ev/with-deadline 0.01 …)" (錯 |(ev/with-deadline 0.01 (ev/take never))))
(列 "wg.Wait()" "(ev/gather …)" (ev/gather (do (ev/sleep 0.002) 1) (do (ev/sleep 0.001) 2)))
(def worker (ev/go (fn [] (try (forever (ev/sleep 0.001)) ([e] [:got e])))))
(ev/sleep 0.005)   # 讓 worker 先跑進 try，否則 cancel 打在它開始前
(ev/cancel worker "cancelled")
(ev/sleep 0.01)
(列 "cancel(); <-ctx.Done()" "(ev/cancel worker …)  合作式" (fiber/status worker))

(節 "真執行緒")
(def tc (ev/thread-chan 1))
(ev/thread (fn [chan] (ev/give chan [:from-thread (* 6 7)])) tc :n)
(列 "go 在另一顆核心跑" "(ev/thread f tc :n) + thread-chan" (ev/take tc))

(print "\n✓ compare-go 跑完——ev 的完整說明在 docs/15")
