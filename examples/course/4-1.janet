# 配合 course/4-1-字串與-buffer.md
# 跑法：janet examples/course/4-1.janet

(print "== 字串改不動 ==")
(def s "abc")
(print (type s))
(printf "%q" (protect (put s 0 120)))
(def s2 (string s "def"))
(print s2 " / 原本的 s 還是 " s)

(print "== buffer 改得動 ==")
(def b @"abc")
(print (type b))
(buffer/push-string b "def")
(print b)
(def b2 @"x")
(buffer/push b2 "y" "z")
(print b2)
(buffer/clear b2)
(printf "%q" b2)
(printf "%q" (buffer "a" 1 :k))

(print "== 兩邊互轉 ==")
(printf "%q" (string @"abc"))
(printf "%q" (buffer "abc"))

(print "== 迴圈裡拼文字 ==")
(def out @"")
(each i [1 2 3]
  (buffer/push out (string i) ","))
(print (string out))

(print "== + 不接字串 ==")
(printf "%q" (protect (+ "a" "b")))
(print (string "a" "b"))
(print (string "id=" 42 " ok=" true))
(print (string/format "%s scored %.2f" "Al" 3.14159))
(print (string/format "%05d" 42))
(printf "%q" (protect (string/format "%s" 42)))

(print "== 坑：= 與 table 鍵 ==")
(print (= "abc" @"abc"))
(print (= "abc" (string @"abc")))
(def t @{})
(put t @"key" 1)
(printf "%q" (get t "key"))
(put t (string @"key") 1)
(printf "%q" (get t "key"))
(printf "%q" (protect (string/format "%d" 3.5)))
(print (string/format "%.0f" 3.5))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1
(print (string "總分 " 90))
# 2
(def acc @"")
(each c ["甲" "乙" "丙"]
  (buffer/push acc c "、"))
(print (string acc))
# 3
(print (string/format "圓周率約 %.2f" 3.14159))
