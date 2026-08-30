# 配合 docs/20-錯誤處理與資源管理.md
#
#   janet examples/errors-raii.janet
#
# 拋錯／接錯的四種工具，以及 defer 與 with——Janet 版的 RAII。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-34s => %j" 說明 結果))

(節 "四種接錯方式")
(秀 "(try (error \"炸\") ([e] e))" (try (error "炸") ([e] e)))
(秀 "(protect (error \"炸\"))" (protect (error "炸")))
(秀 "(protect (+ 1 1))  成功時" (protect (+ 1 1)))
(print "  protect 回 [成功? 值]；try 只給你錯誤本身")
(秀 "errorf 會先組字串" (try (errorf "缺 %s，拿到 %j" ":model" nil) ([e] e)))

(print "\n  ⚠ 錯誤值不一定是字串——你丟什麼它就是什麼：")
(秀 "(try (error {:code 404}) ([e] e))" (try (error {:code 404}) ([e] e)))
(print "    丟 struct 比丟字串好接：呼叫端可以 match :code（見 docs/32）")

(節 "catch 的第二個參數是出錯當下的 fiber")
(defn 裡 [x] (error "最裡面炸了"))
(defn 外 [x] (+ 1 (裡 x)))
(print "  （堆疊走 stderr，可能印在最上面——見 docs/34）")
(try (外 1) ([e f] (debug/stacktrace f e "")))
(print "  ⚠ 第三個參數 \"\" 不能省，省了就不印 error: 那一行")

(節 "defer：正常結束、提早跳出、拋錯，三種都會收尾")
(print "  ① 正常結束：")
(defn 正常 [] (defer (print "    收尾") (print "    body 跑完")))
(正常)

(print "  ② 迴圈裡提早 break：")
(defn 提早 []
  (defer (print "    收尾")
    (each i [1 2 3]
      (when (= i 2) (break))
      (printf "    i=%d" i))))
(提早)

(print "  ③ 拋錯：")
(defn 拋錯 [] (defer (print "    收尾") (error "炸了")))
(try (拋錯) ([e] (printf "    例外照樣往外傳：%s" e)))
(print "  這就是解構子給你的保證。⚠ 參數順序跟 Go 相反——收尾動作寫前面")

(秀 "defer 回傳的是 body 的值" (defer nil :body的值))

(節 "巢狀 defer 是 LIFO，跟 C++ 解構子一樣")
(defer (print "    外層收尾")
  (defer (print "    內層收尾")
    (print "    body")))

(節 "with：開了就一定關")
(def Conn @{:close (fn [self] (print "    (:close) 被呼叫"))
            :query (fn [self q] (printf "    查詢 %s" q))})
(defn connect [] (table/setproto @{} Conn))

(print "  正常結束：")
(with [c (connect)] (:query c "select 1"))

(print "  body 拋錯時照樣關：")
(try (with [c (connect)] (error "查到一半炸了"))
     ([e] (printf "    接到：%s" e)))

(print "\n  第三個位置可以自訂收尾函式（物件沒有 :close 時用）：")
(defn 開資源 [] @{:名 "檔案把手"})
(defn 自己關 [r] (printf "    自訂收尾關掉「%s」" (r :名)))
(with [r (開資源) 自己關] (print "    使用中"))

(printf "\n  %-32s => %s" "沒有 :close 又沒給收尾函式"
        (try (with [r @{}] :ok) ([e] (string "報錯：" e))))
(print "    ↑ 這句「unknown method :close invoked on」就是 docs/34 那張表裡的一列")

(節 "心法：with = 局部作用域版的 RAII")
(print "  C++：物件活多久，資源活多久")
(print "  Janet：這個區塊多長，資源活多長")
(print "  因為有 GC，「物件被回收時」的時機不可預期，所以 Janet 乾脆綁在明確的區塊上")
(print "  ⚠ 推論：別把 file handle 存進長命的 table 然後指望它會被關掉")
(print "     handle 一定要有一個明確的擁有者（某個 with 區塊）決定何時關")

(節 "assert 不會被最佳化掉")
(秀 "(assert 5 \"訊息\")  回的是被檢查的值" (assert 5 "訊息"))
(秀 "失敗時" (try (assert nil "前提條件沒滿足") ([e] e)))
(print "  Janet 沒有 NDEBUG——assert 就是一般的執行期檢查")
(print "  在動態型別語言裡，它是補回型別檢查最省力的方式")

(print "\n✓ errors-raii 跑完")
