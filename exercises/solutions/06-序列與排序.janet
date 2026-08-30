# 練習 06 的參考解答
#
#   janet exercises/solutions/06-序列與排序.janet

# 1. ⚠ Janet 的排序**不穩定**——只排 :齡 的話，同齡的相對順序沒保證（docs/36）。
#    解法是把決勝鍵放進 key：tuple 是**逐格比**的，第一格同才比第二格。
(defn 排人 [人們]
  (map |($ :名) (sorted-by |[($ :齡) ($ :名)] 人們)))

# 2. ⚠ 比較器是「a 該排在 b 前面嗎」，回**真假**不是 -1/0/1。
#    傳 compare 進去會算出垃圾，因為 0 在 Janet 是真（docs/36）。
#    由長到短＝「長的排前面」＝ >。
(defn 由長到短 [xs]
  (sorted-by |(- (length $)) xs))

# 3. 走一遍推進對應的桶，順序自然保住。
#    （spork/misc 也有 group-by，但這裡自己寫比較看得出順序怎麼保的）
(defn 分奇偶 [xs]
  (def 奇 @[]) (def 偶 @[])
  (each x xs (array/push (if (odd? x) 奇 偶) x))
  @{:奇 奇 :偶 偶})

# 4. frequencies 回 @{值 次數}，挑次數最大的那個鍵。
#    ⚠ 別依賴 (keys …) 的順序——那是 hash 序（docs/25）。這裡靠比大小，沒問題。
(defn 最常出現 [xs]
  (def 次 (frequencies xs))
  (var 最佳 nil)
  (eachk k 次
    (when (or (nil? 最佳) (> (get 次 k) (get 次 最佳)))
      (set 最佳 k)))
  最佳)

# 5. ⚠ :while 一假就中止、:when 只是過濾——兩個都要（docs/32b）。
#    「只收前 4 個」需要一個計數器，因為 loop 沒有「收滿就停」的 verb。
(defn 前四個 [n]
  (def out @[])
  (loop [i :range [0 n]
         :while (< (length out) 4)
         :when (zero? (mod i 3))]
    (array/push out (* i i)))
  out)

# 6. catseq 就是「推導完再攤平一層」，一次做完（docs/25）。
#    也可以 (array/concat @[] ;xss)，但那個 ;xss 的攤平規則要另外記。
(defn 攤平一層 [xss]
  (catseq [xs :in xss] xs))

# ── 檢查 ──────────────────────────────────────────────────────

(def 人們
  [{:名 "David" :齡 30} {:名 "Alice" :齡 25}
   {:名 "Carol" :齡 30} {:名 "Bob" :齡 25}])

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯) (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j" n 說明 預期 實得))))

(檢查 1 "多鍵排序" (排人 人們) @["Alice" "Bob" "Carol" "David"])
(檢查 2 "由長到短" (由長到短 ["bb" "a" "cccc" "ddd"]) @["cccc" "ddd" "bb" "a"])
(檢查 3 "分奇偶"
       (let [r (分奇偶 [3 1 4 1 5 9 2 6])] [(get r :奇) (get r :偶)])
       [@[3 1 1 5 9] @[4 2 6]])
(檢查 4 "最常出現" (最常出現 [1 2 2 3 2 1]) 2)
(檢查 5 "前四個" (前四個 100) @[0 9 36 81])
(檢查 6 "攤平一層" (攤平一層 [[1 2] [3] [4 5]]) @[1 2 3 4 5])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(assert (zero? 錯) "參考解答自己沒過——那就是解答寫錯了")
(print "✓ 參考解答全部通過")
