# 練習 03 · 字串與型別
#
#   janet exercises/03-字串與型別.janet
#
# 這一份圍繞同一件事：**byte ≠ 字元 ≠ 顯示寬度**，以及四種「名字」互不相等。
# 答案在 exercises/solutions/03-字串與型別.janet。

(import spork/rawterm)

(def 未完成 :還沒寫)

# ── 題目 ──────────────────────────────────────────────────────

# 1. 回一個字串的**字元數**（不是 byte 數）。
#    ⚠ (length "中文") 是 6（見 docs/18）。
(defn 字元數 [s]
  未完成)

# 2. 把字串補到指定的**顯示寬度**（中文佔兩格），不足補空白。
#    ⚠ printf 的 %-10s 數的是 byte，中文欄會歪（見 docs/41）。
(defn 補到寬 [s w]
  未完成)

# 3. 判斷兩個「看起來一樣」的名字是不是同一個東西。
#    ⚠ 跨型別的 = 一律 false，連 buffer 跟 string 都不相等（見 docs/13）。
#    回 true 只有在「轉成字串後內容相同」的時候。
(defn 名字相同? [a b]
  未完成)

# 4. 把 JSON 解出來那種**字串 key** 的 table 轉成 **keyword key**。
(defn 轉keyword鍵 [t]
  未完成)

# 5. 判斷一個值「能不能安全地丟給 (length …)」。
#    ⚠ 數字、nil、函式都不行；四種名字型別跟四種容器都可以（見 docs/38）。
(defn 有長度? [x]
  未完成)

# 6. 把字串轉成數字；轉不成回 nil 而不是拋錯，而且**空字串也要回 nil**。
#    ⚠ scan-number 失敗回 nil（好），但 (scan-number "") 也回 nil，要一起處理。
(defn 轉數字 [s]
  未完成)

# ── 檢查（不用改這裡）──────────────────────────────────────────

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 提示 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯)
        (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j\n    提示 %s"
                n 說明 預期 實得 提示))))

(檢查 1 "字元數不是 byte 數" "docs/18：一個中文字是 3 個 byte"
       [(字元數 "abc") (字元數 "中文") (字元數 "中文abc")]
       [3 2 5])

(檢查 2 "補到顯示寬度" "docs/41：rawterm/monowidth 才是顯示寬度"
       [(補到寬 "abc" 6) (補到寬 "中文" 6)]
       ["abc   " "中文  "])

(檢查 3 "名字是不是同一個" "docs/13：跨型別 = 一律 false，先轉成字串再比"
       [(名字相同? "abc" :abc) (名字相同? "abc" @"abc")
        (名字相同? 'abc :abc) (名字相同? "abc" "abd")]
       [true true true false])

(檢查 4 "字串 key 轉 keyword key" "docs/13：(keyword k)"
       (轉keyword鍵 {"name" "Al" "age" 3})
       @{:name "Al" :age 3})

(檢查 5 "能不能 length" "docs/38：lengthable?"
       (map 有長度? ["s" @"b" 'sym :kw [1] @[1] {:a 1} @{:a 1} 5 nil])
       @[true true true true true true true true false false])

(檢查 6 "字串轉數字" "docs/38：scan-number 失敗回 nil；空字串也要擋"
       [(轉數字 "42") (轉數字 "3.5") (轉數字 "abc") (轉數字 "")]
       [42 3.5 nil nil])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(if (zero? 錯)
  (print "✓ 全部通過")
  (print "改一題跑一次就好，不用一次寫完。"))
