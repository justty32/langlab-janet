# 練習 05 · 錯誤與資源
#
#   janet exercises/05-錯誤與資源.janet
#
# 從 C++ 過來的人會把 with 當 RAII——大致沒錯，但差別在細節。
# 答案在 exercises/solutions/05-錯誤與資源.janet。

(def 未完成 :還沒寫)

# ── 題目 ──────────────────────────────────────────────────────

# 1. 跑一個可能失敗的函式，成功回 [true 值]、失敗回 [false 錯誤]。
#    ⚠ 不要自己用 try 組——內建就有（見 docs/20）。
(defn 試跑 [f]
  未完成)

# 2. 解析一個 "key=value" 字串，回 [鍵 值]。格式不對就**拋錯**，
#    錯誤訊息要包含原字串，方便呼叫端定位。
#    ⚠ 用 errorf 一次組好（見 docs/20）。
(defn 解析一行 [s]
  未完成)

# 3. 寫一個「一定會收尾」的函式：不管 body 正常結束還是拋錯，
#    都要往 log 陣列推一筆 :收尾了；拋錯時例外照樣往外傳。
#    ⚠ 參數順序跟 Go 相反（見 docs/20b）。
(defn 一定收尾 [log body]
  未完成)

# 4. 做一個有 :close 的「假連線」物件，讓它能配合 with 用。
#    回一個工廠函式，(工廠) 回一個新連線；連線被關掉時往 log 推 :關了。
(defn 做連線工廠 [log]
  未完成)

# 5. 把「查不到就回 nil」的風格，包成「查不到就拋錯」的風格。
#    (必須有 t :k) 拿得到就回值，拿不到就拋錯且訊息含那個鍵。
(defn 必須有 [t k]
  未完成)

# 6. 收集一批工作的結果：成功的收進 :ok，失敗的收進 :err，
#    **一個失敗不能中斷其他的**。回 @{:ok @[…] :err @[…]}。
(defn 全部跑完 [fs]
  未完成)

# ── 檢查（不用改這裡）──────────────────────────────────────────

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 提示 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯)
        (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j\n    提示 %s"
                n 說明 預期 實得 提示))))

(檢查 1 "試跑" "docs/20：protect 就是這個"
       [(試跑 (fn [] 42)) (試跑 (fn [] (error "壞了")))]
       [[true 42] [false "壞了"]])

(檢查 2 "解析一行" "docs/20：errorf"
       [(試跑 (fn [] (解析一行 "a=1")))
        (first (試跑 (fn [] (解析一行 "沒有等號"))))
        (truthy? (string/find "沒有等號" (string (last (試跑 (fn [] (解析一行 "沒有等號")))))))]
       [[true ["a" "1"]] false true])

(def log3 @[])
(檢查 3 "一定收尾（正常）" "docs/20b：defer 的收尾動作寫在前面"
       (do (array/clear log3) [(一定收尾 log3 (fn [] :做完)) (tuple ;log3)])
       [:做完 [:收尾了]])
(檢查 3 "一定收尾（拋錯時也要收，而且例外往外傳）" "docs/20b"
       (do (array/clear log3)
           [(first (試跑 (fn [] (一定收尾 log3 (fn [] (error "炸")))))) (tuple ;log3)])
       [false [:收尾了]])

(def log4 @[])
(檢查 4 "with 配 :close" "docs/20b：物件有 :close，with 就會呼叫"
       (let [工廠 (做連線工廠 log4)]
         (if (function? 工廠)
           (do (array/clear log4)
               (with [c (工廠)] :用完了)
               (tuple ;log4))
           :還沒寫))
       [:關了])

(檢查 5 "必須有" "docs/20：查不到就 errorf，訊息含鍵名"
       [(試跑 (fn [] (必須有 {:a 1} :a)))
        (first (試跑 (fn [] (必須有 {:a 1} :zz))))
        (truthy? (string/find "zz" (string (last (試跑 (fn [] (必須有 {:a 1} :zz)))))))]
       [[true 1] false true])

(檢查 6 "一個失敗不中斷其他" "docs/20：每個工作各自 protect"
       (let [r (全部跑完 [(fn [] 1) (fn [] (error "第二個壞")) (fn [] 3)])]
         (if (dictionary? r) [(get r :ok) (length (get r :err))] r))
       [@[1 3] 1])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(if (zero? 錯)
  (print "✓ 全部通過")
  (print "改一題跑一次就好，不用一次寫完。"))
