# 配合 course/4-2-字串常用招式.md
# 跑法：janet examples/course/4-2.janet

(print "== 切開、接回 ==")
(printf "%q" (string/split "," "a,b,c"))
(printf "%q" (string/split "," "a,,c"))
(print (string/join @["a" "b" "c"] ", "))
(printf "%q" (protect (string/join [1 2] "-")))
(print (string/join (map string [1 2 3]) "-"))

(print "== 找、換 ==")
(print (string/find "lo" "hello"))
(printf "%q" (string/find "z" "hello"))
(print (string/replace "a" "X" "banana"))
(print (string/replace-all "a" "X" "banana"))
(print (if (string/find "world" "hello world") "有 world" "沒有 world"))

(print "== 去空白、看頭尾 ==")
(printf "%q" (string/trim "  hi \n"))
(printf "%q" (string/triml "  hi  "))
(print (string/has-prefix? "http://" "http://x.com"))
(print (string/has-suffix? ".janet" "main.janet"))

(print "== 切片、大小寫、重複 ==")
(print (string/slice "hello" 1 3))
(print (string/slice "hello" -3))
(print (string/ascii-upper "abc"))
(print (string/repeat "ab" 3))

(print "== 對齊排版 ==")
(print (string/format "%-6s|%2d" "apple" 3))
(print (string/format "%5.2f" 3.14159))
(print (string/format "%d%%" 50))

(print "== 字串變數字 ==")
(print (scan-number "42"))
(print (scan-number "3.5"))
(printf "%q" (scan-number "abc"))
(printf "%q" (protect (+ 1 "2")))

(print "== 串起來用 ==")
(def line "  10, 20, 30  ")
(def parts (string/split "," (string/trim line)))
(printf "%q" parts)
(def nums (map scan-number (map string/trim parts)))
(printf "%q" nums)
(print (sum nums))

(print "== 坑：byte 不是字 ==")
(print (length "hello"))
(print (length "你好"))
(printf "%q" (string/bytes "你"))
(print (get "hello" 0))
(print (string/slice "你好" 0 3))
(printf "%q" (string/slice "你好" 0 1))
(print (string/find "好" "你好"))
(printf "%q" (string/split "a,b,c" ","))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1
(print (string/join (map string/ascii-upper (string/split " " "the quick fox")) " "))
# 2
(when (string/has-suffix? ".janet" "main.janet")
  (print "是 Janet 檔"))
# 3
(print (length (string/split "、" "甲、乙、丙")))
