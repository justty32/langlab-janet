# 練習 01 的參考解答
#
#   janet exercises/solutions/01-資料與比較.janet
#
# 「參考」的意思是：能過就好，這不是唯一寫法。重點在每題底下那句「為什麼」。

# 1. ⚠ 可變容器的 = 比的是身分（是不是同一個物件），不是內容。
#    比內容一律用 deep=——寫測試時尤其常忘（docs/02、docs/23）。
(defn 內容相同? [a b] (deep= a b))

# 2. ⚠ table/clone 只複製一層，內層還是同一個物件。
#    深拷貝＝「凍起來再解開」，因為 freeze 保證走遍每一層（docs/35）。
(defn 深拷貝 [t] (thaw (freeze t)))

# 3. 用一張 table 記「看過沒」，順序靠走訪順序保住。
#    ⚠ 別用 (keys (frequencies xs))——那出來是 hash 序，不是第一次出現的順序。
(defn 去重 [xs]
  (def 看過 @{})
  (def out @[])
  (each x xs
    (unless (get 看過 x)
      (put 看過 x true)
      (array/push out x)))
  out)

# 4. ⚠ array 當鍵取不回來（比身分）；tuple 可以（比內容）。
#    所以複合鍵要用 [x y] 不是 @[x y]（docs/02、docs/35）。
(defn 座標表 [x y 值]
  (def t @{})
  (put t [x y] 值)
  t)

# 5. ⚠ (keys t) 是 hash 序——跨行程穩定，但不是插入序也不是排序。
#    要固定輸出就自己 sort（docs/25）。
#    ⚠ 順手踩到第二個：**`%s` 只吃字串類**（string/buffer/symbol/keyword），
#      餵數字會報「bad slot #2, expected string, symbol, keyword or buffer, got 1」。
#      要通吃就用 `%v`，或自己 (string v)（docs/18）。
(defn 穩定字串 [t]
  (string/join
    (seq [k :in (sort (keys t))]
      (string/format "%s=%v" k (get t k)))
    ","))

# 6. ⚠ merge 一律回 table，即使兩邊都是 struct（docs/35b）。
#    要不可變就再 freeze 一次。
(defn 合併成不可變 [a b] (freeze (merge a b)))

# ── 檢查（跟題目那份一樣）──────────────────────────────────────

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 提示 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯)
        (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j" n 說明 預期 實得))))

(檢查 1 "內容相同的 array" ""
       [(內容相同? @[1 2] @[1 2]) (內容相同? @[1 2] @[1 3])] [true false])

(def 原 @{:a @[1 2]})
(def 拷 (深拷貝 原))
(array/push (get 原 :a) 99)
(檢查 2 "深拷貝之後改原本，拷貝不受影響" "" (get 拷 :a) @[1 2])

(檢查 3 "拿掉重複的元素" "" (去重 [3 1 3 2 1]) @[3 1 2])

(檢查 4 "用座標當字典的鍵" "" (get (座標表 3 4 :寶藏) [3 4]) :寶藏)

(檢查 5 "順序固定的字串" "" (穩定字串 @{:b 2 :a 1}) "a=1,b=2")

(檢查 6 "合併成不可變" ""
       (let [r (合併成不可變 {:a 1} {:b 2 :a 9})]
         [(type r) (get r :a) (get r :b)])
       [:struct 9 2])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(assert (zero? 錯) "參考解答自己沒過——那就是解答寫錯了")
(print "✓ 參考解答全部通過")
