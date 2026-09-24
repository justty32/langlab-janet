# 配合 course/1-1-裝好跑起來.md
# 跑法：janet examples/course/1-1.janet

(print "== 算第一個式子 ==")
# 在 REPL 裡打 (+ 1 2) 會自動印出 3。
# 在檔案裡不會自動印，所以要包一層 print。
(print (+ 1 2))

(print "== 沒打完，它會等你 ==")
# 一個式子可以拆成好幾行寫，括號關起來才算完。
(print (+ 1
          2))

(print "== 跑一支檔案 ==")
# 這就是課文裡 hello.janet 的內容。
(print "hello, Janet")
(print (+ 1 2))

(print "== 坑：檔案裡不會自動印結果 ==")
(+ 1 2)   # 這行有算，但什麼都不印
(print "上面那行 (+ 1 2) 算完了，只是沒有印出來")

# ---- 練習解答 ----
(print "== 練習解答 ==")

# 1. 在 REPL 裡打：
#      repl:1:> (* 6 7)
#      42
#      repl:2:> (quit)
#    這裡用 print 印出同一個結果：
(print (* 6 7))

# 2. me.janet 的內容（名字換成你自己的），用 janet me.janet 跑：
(print "小明")
(print (+ 100 23))

# 3. 在終端機打：
#      janet -e '(print (* 6 7))'
#    會印出 42。
