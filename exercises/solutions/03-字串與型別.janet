# 練習 03 的參考解答
#
#   janet exercises/solutions/03-字串與型別.janet

(import spork/utf8)
(import spork/rawterm)

# 1. ⚠ (length "中文") 是 6——那是 **byte** 數（docs/18）。
#    spork/utf8 只給三個原語，沒有 length，字元數要自己疊：
#    看第一個 byte 就知道這個字元佔幾個 byte，跳著走。
#    （完整版見 snippets/utf8-strings.janet 的 runes）
(defn 字元數 [s]
  (var i 0) (var n 0)
  (def 長 (length s))
  (while (< i 長)
    (+= i (utf8/prefix->width (in s i)))
    (++ n))
  n)

# 2. ⚠ 第三個數字又不一樣了：byte 數 6、字元數 2、**顯示寬度 4**（中文佔兩格）。
#    printf 的 %-6s 數的是 byte，所以中文欄一定歪（docs/41）。
(defn 補到寬 [s w]
  (string s (string/repeat " " (max 0 (- w (rawterm/monowidth s))))))

# 3. ⚠ 跨型別的 = 一律 false，連 buffer 跟 string 內容一樣也不相等（docs/13）。
#    先全部轉成 string 再比。
(defn 名字相同? [a b] (= (string a) (string b)))

# 4. tabseq 一行搞定。JSON 解出來常是字串 key，
#    （spork/json 的 :keywords 參數可以直接要它這樣解，見 docs/03）
(defn 轉keyword鍵 [t]
  (tabseq [[k v] :pairs t] (keyword k) v))

# 5. 直接用內建的傘狀判斷函式——它罩住四種名字型別 ＋ 四種容器（docs/38）。
#    自己寫 (or (string? x) (array? x) …) 會漏掉 buffer、symbol、keyword。
(defn 有長度? [x] (truthy? (lengthable? x)))

# 6. ⚠ scan-number 失敗回 nil 不拋錯（好事），但空字串也回 nil，
#    而且有些版本對 "" 的行為不直覺——自己先擋掉最保險（docs/38）。
(defn 轉數字 [s]
  (if (or (not (string? s)) (empty? s))
    nil
    (scan-number s)))

# ── 檢查 ──────────────────────────────────────────────────────

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯) (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j" n 說明 預期 實得))))

(檢查 1 "字元數不是 byte 數"
       [(字元數 "abc") (字元數 "中文") (字元數 "中文abc")] [3 2 5])
(檢查 2 "補到顯示寬度"
       [(補到寬 "abc" 6) (補到寬 "中文" 6)] ["abc   " "中文  "])
(檢查 3 "名字是不是同一個"
       [(名字相同? "abc" :abc) (名字相同? "abc" @"abc")
        (名字相同? 'abc :abc) (名字相同? "abc" "abd")]
       [true true true false])
(檢查 4 "字串 key 轉 keyword key"
       (轉keyword鍵 {"name" "Al" "age" 3}) @{:name "Al" :age 3})
(檢查 5 "能不能 length"
       (map 有長度? ["s" @"b" 'sym :kw [1] @[1] {:a 1} @{:a 1} 5 nil])
       @[true true true true true true true true false false])
(檢查 6 "字串轉數字"
       [(轉數字 "42") (轉數字 "3.5") (轉數字 "abc") (轉數字 "")]
       [42 3.5 nil nil])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(assert (zero? 錯) "參考解答自己沒過——那就是解答寫錯了")
(print "✓ 參考解答全部通過")
