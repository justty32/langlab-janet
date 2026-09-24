# 配合 course/2-2-把東西印出來.md
# 跑法：janet examples/course/2-2.janet

(print "== print 與 prin ==")
(print "x" "y" 1 nil :k)        # 接起來印，中間不加空格，尾端換行
(prin "a")                      # 不換行
(prin "b")
(print)                         # 只補一個換行

(print "== printf 與 prinf ==")
(printf "%d %f %x %.2f %5d|%-5d|" 42 3.5 255 3.14159 7 7)
(prinf "%d" 1)
(prinf "%d" 2)
(print)
# 兩個會炸的：%d 給小數、%s 給數字。用 protect 包住把錯誤訊息印出來。
(pp (protect (printf "%d" 3.7)))
(pp (protect (printf "%s" 42)))

(print "== string/format 與 string ==")
(def line (string/format "%s scored %.2f" "Al" 3.14159))
(print line)                    # Al scored 3.14
(print (string "id=" 42 " ok=" true))   # id=42 ok=true

(print "== %s %q %j 差在哪 ==")
(print (string/format "%s" "hi"))       # hi         給人看
(print (string/format "%q" "hi"))       # "hi"       Janet 寫法，帶引號
(print (string/format "%j" @[1 2]))     # @[1 2]     容器印內容
(print (string/format "%j" 42))         # 42         %j 什麼型別都收
(printf "%p" {:name "Al" :tags @["a" "b"]})   # %p 漂亮排版

(print "== pp ==")
(pp @[1 2 3])
(pp @{:a 1})

(print "== 坑一：print 印容器只有位址 ==")
(print @[1 2 3])                # <array 0x...>，位址每次不同
(pp @[1 2 3])                   # @[1 2 3]
(printf "%j" @[1 2 3])          # @[1 2 3]
# %s 給容器也是報錯（訊息裡帶位址，所以這裡只印前半）
(def [ok msg] (protect (string/format "%s" @[1 2])))
(print ok " " (string/slice msg 0 40) "...")

(print "== 坑二：中文被逃逸 ==")
(print (string/format "%j" "你好"))     # "\xE4\xBD\xA0\xE5\xA5\xBD"
(pp "你好")                             # 同上
(print "你好")                          # 你好
(printf "%s\n" "你好")                  # 你好（%s 給人看；這裡故意多一個 \n 給你看多出的空行）

(print "== 順帶：xprint ==")
(flush)                         # 先把 stdout 排空，stderr 那行才不會插隊
(xprint stderr "這行印到 stderr，終端機還是看得到")

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. prin 不換行，最後 print 換行
(prin 1 " ")
(prin 2 " ")
(print 3)
# 2. %4d 靠右補到四格；string/format 回傳字串，不印
(def s (string/format "[%4d] done" 42))
(pp s)                          # "[  42] done"，用 pp 看得到引號
# 3. 兩種方法印出容器內容
(pp @[1 "a" :k])
(printf "%j" @[1 "a" :k])
