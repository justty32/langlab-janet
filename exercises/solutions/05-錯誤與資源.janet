# 練習 05 的參考解答
#
#   janet exercises/solutions/05-錯誤與資源.janet

# 1. 內建就有——protect 回 [成功? 值]，很像 Rust 的 Result（docs/20）。
#    自己用 try 組也行，但沒必要。
(defn 試跑 [f] (protect (f)))

# 2. ⚠ errorf 一次把訊息組好。往上拋之前**補上下文**，別讓一個
#    "格式不對" 從三層底下冒出來（docs/20 最後一節）。
#    ⚠ 第二個坑：訊息裡的原字串用 **%s 不用 %q**——%q 會把中文逃逸成
#    \xE6\xB2\x92…，呼叫端想從訊息裡找關鍵字就找不到（docs/01）。
#    要顯示前後空白之類的細節才值得用 %q，一般錯誤訊息是給人看的。
(defn 解析一行 [s]
  (def i (string/find "=" s))
  (unless i (errorf "不是 key=value 格式：%s" s))
  [(string/slice s 0 i) (string/slice s (inc i))])

# 3. ⚠ defer 的參數順序跟 Go **相反**：收尾動作寫在**前面**，body 在後面（docs/20b）。
#    正常結束、提早 break、拋錯，三種情況都會執行——這就是解構子給你的保證。
(defn 一定收尾 [log body]
  (defer (array/push log :收尾了)
    (body)))

# 4. with 預設呼叫該值的 :close 方法。物件就是一張帶 :close 的 table（docs/22、20b）。
#    ⚠ body 拋錯時 :close 照樣會被呼叫——那才是它等同 RAII 的地方。
(defn 做連線工廠 [log]
  (def 原型 @{:close (fn [self] (array/push log :關了))})
  (fn [] (table/setproto @{} 原型)))

# 5. ⚠ 內建函式分兩派：查不到很正常的回 nil（get、string/find），
#    本來就該成功的拋錯（slurp、json/decode）。這題是把前者包成後者（docs/20）。
#    用 has-key? 不用 (get t k)——值本身可能就是 nil。
(defn 必須有 [t k]
  (unless (has-key? t k) (errorf "設定裡少了 %q" k))
  (get t k))

# 6. ⚠ protect 要包在**每個工作內部**，不是整批外面——
#    包在外面的話第一個失敗就中斷了（docs/20、snippets/parallel-batch）。
(defn 全部跑完 [fs]
  (def ok @[]) (def err @[])
  (each f fs
    (def [成功? v] (protect (f)))
    (array/push (if 成功? ok err) v))
  @{:ok ok :err err})

# ── 檢查 ──────────────────────────────────────────────────────

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯) (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j" n 說明 預期 實得))))

(檢查 1 "試跑" [(試跑 (fn [] 42)) (試跑 (fn [] (error "壞了")))]
       [[true 42] [false "壞了"]])

(檢查 2 "解析一行"
       [(試跑 (fn [] (解析一行 "a=1")))
        (first (試跑 (fn [] (解析一行 "沒有等號"))))
        (truthy? (string/find "沒有等號" (string (last (試跑 (fn [] (解析一行 "沒有等號")))))))]
       [[true ["a" "1"]] false true])

(def log3 @[])
(array/clear log3)
(檢查 3 "一定收尾（正常）"
       [(一定收尾 log3 (fn [] :做完)) (tuple ;log3)] [:做完 [:收尾了]])
(array/clear log3)
(檢查 3 "一定收尾（拋錯時也收，例外往外傳）"
       [(first (試跑 (fn [] (一定收尾 log3 (fn [] (error "炸")))))) (tuple ;log3)]
       [false [:收尾了]])

(def log4 @[])
(def 工廠 (做連線工廠 log4))
(with [c (工廠)] :用完了)
(檢查 4 "with 配 :close" (tuple ;log4) [:關了])

(檢查 5 "必須有"
       [(試跑 (fn [] (必須有 {:a 1} :a)))
        (first (試跑 (fn [] (必須有 {:a 1} :zz))))
        (truthy? (string/find "zz" (string (last (試跑 (fn [] (必須有 {:a 1} :zz)))))))]
       [[true 1] false true])

(檢查 6 "一個失敗不中斷其他"
       (let [r (全部跑完 [(fn [] 1) (fn [] (error "第二個壞")) (fn [] 3)])]
         [(get r :ok) (length (get r :err))])
       [@[1 3] 1])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(assert (zero? 錯) "參考解答自己沒過——那就是解答寫錯了")
(print "✓ 參考解答全部通過")
