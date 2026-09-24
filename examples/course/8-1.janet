# 配合 course/8-1-讀寫檔案.md
# 續篇 course/8-1b-讀寫檔案.md 的段落也在這支；所有檔案寫在暫存目錄，跑完一一刪掉。

(def tmp (string (or (os/getenv "TMPDIR") "/tmp") "/janet-course-8-1"))
(os/mkdir tmp)
(defn at [name] (string tmp "/" name))

(print "== spit 寫、slurp 讀 ==")
(printf "spit 回傳 %j" (spit (at "hello.txt") "hello\n"))
(printf "slurp 讀回 %j" (slurp (at "hello.txt")))
(os/rm (at "hello.txt"))

(print "== 在檔尾接著寫 ==")
(spit (at "log.txt") "第一行\n")
(spit (at "log.txt") "第二行\n" :ab)
(prin (slurp (at "log.txt")))
(os/rm (at "log.txt"))

(print "== 檔案不在時怎麼辦 ==")
(def missing (at "沒有這個檔.txt"))
(printf "protect 的第一格 %j" (first (protect (slurp missing))))
(printf "os/stat 回 %j" (os/stat missing))
(printf "try 接住後 %j" (try (slurp missing) ([_] "default")))

(print "== 坑：buffer 跟字串比 ==")
(spit (at "hi.txt") "hi\n")
(printf "直接比 %j" (= "hi\n" (slurp (at "hi.txt"))))
(printf "轉字串再比 %j" (= "hi\n" (string (slurp (at "hi.txt")))))
(os/rm (at "hi.txt"))

(print "== 寫檔和模式字串 ==")
(with [f (file/open (at "fruits.txt") :w)]
  (file/write f "apple\n")
  (:write f "banana\n" "cherry\n"))
(printf "%j" (slurp (at "fruits.txt")))
(os/rm (at "fruits.txt"))

(print "== 一行一行讀 ==")
(spit (at "lines.txt") "one\ntwo\n")
(with [f (file/open (at "lines.txt") :r)]
  (while (def line (file/read f :line))
    (prin "讀到：" line)))
(os/rm (at "lines.txt"))

(spit (at "abc.txt") "hello\nworld\n")
(printf "讀 3 bytes %j" (with [f (file/open (at "abc.txt"))] (file/read f 3)))
(printf "讀 :all %j" (with [f (file/open (at "abc.txt"))] (file/read f :all)))
(os/rm (at "abc.txt"))

(print "== 坑：打不開的檔案不會馬上報錯 ==")
(printf "file/open 回 %j" (file/open missing))
(printf "%j" (protect (with [f (file/open missing)] (file/read f :all))))

# ---- 練習解答 ----
(print "== 練習解答 ==")

# 1. 數行數
(defn count-lines [path]
  (var n 0)
  (with [f (file/open path :r)]
    (while (file/read f :line) (++ n)))
  n)
(spit (at "three.txt") "a\nb\nc\n")
(printf "count-lines => %j" (count-lines (at "three.txt")))
(os/rm (at "three.txt"))

# 2. 安全讀檔：不在就回 ""
(defn safe-read [path]
  (try (string (slurp path)) ([_] "")))
(spit (at "safe.txt") "ok\n")
(printf "safe-read 在 => %j" (safe-read (at "safe.txt")))
(printf "safe-read 不在 => %j" (safe-read missing))
(os/rm (at "safe.txt"))

# 3. 用 :ab 連寫三行 log
(each msg ["start" "working" "done"]
  (spit (at "app.log") (string msg "\n") :ab))
(def lines (string/split "\n" (string/trimr (slurp (at "app.log")))))
(printf "log 有 %d 行：%j" (length lines) lines)
(os/rm (at "app.log"))

(os/rm tmp)
