# 配合 course/8-2-目錄與路徑.md（續篇 8-2b-目錄與路徑.md）
(import spork/path)

(def tmp (string (or (os/getenv "TMPDIR") "/tmp") "/janet-course-8-2"))

(print "== os/stat 查檔案資訊 ==")
(os/mkdir tmp)
(def f (path/join tmp "a.txt"))
(spit f "hello\n")
(printf "%j" (sort (keys (os/stat f))))
(printf ":size     %j" (os/stat f :size))
(printf ":mode     %j" (os/stat f :mode))
(printf "目錄 mode %j" (os/stat tmp :mode))
(print ":modified " (os/stat f :modified))
(os/rm f)

(print "== 存不存在 ==")
(defn exists? [p] (truthy? (os/stat p)))
(defn dir? [p] (= :directory (os/stat p :mode)))
(printf "%j" (os/stat "no-such-8-2.txt"))
(printf "exists? %j" (exists? "no-such-8-2.txt"))
(printf "dir? %j" (dir? tmp))

(print "== 建目錄、刪東西 ==")
(printf "再建一次 tmp：%j" (os/mkdir tmp))
(printf "建 sub：%j" (os/mkdir (path/join tmp "sub")))
(spit (path/join tmp "sub" "x.txt") "1")
(def r (protect (os/rm (path/join tmp "sub"))))
(printf "刪非空目錄：%j" (r 0))
(print "錯誤訊息：" (r 1))
(os/rm (path/join tmp "sub" "x.txt"))
(os/rm (path/join tmp "sub"))

(print "== os/dir 列目錄 ==")
(spit (path/join tmp "b.txt") "b")
(spit (path/join tmp "a.txt") "a")
(os/mkdir (path/join tmp "sub"))
(spit (path/join tmp "sub" "deep.txt") "d")
(print "原始順序：" (string/join (os/dir tmp) " "))
(printf "排序後：%j" (sort (os/dir tmp)))
(os/rm (path/join tmp "sub" "deep.txt"))
(os/rm (path/join tmp "sub"))
(os/rm (path/join tmp "a.txt"))
(os/rm (path/join tmp "b.txt"))

(print "== os/cwd 與 os/which ==")
(print "cwd：" (os/cwd))
(printf "which：%j" (os/which))

(print "== spork/path 組路徑 ==")
(printf "%j" (path/join "a" "b" "c.txt"))
(printf "string 接：%j" (string "out/" "/data.txt"))
(printf "path/join：%j" (path/join "out/" "/data.txt"))
(printf "basename %j" (path/basename "a/b/c.txt"))
(printf "dirname  %j" (path/dirname "a/b/c.txt"))
(printf "ext      %j %j %j" (path/ext "a/b/c.txt") (path/ext "a.tar.gz") (path/ext "Makefile"))
(print "abspath  " (path/abspath "x"))
(printf "%j" (protect (os/mkdir "no-such-8-2/deep")))

(print "== 小工具：.txt 行數加總 ==")
(spit (path/join tmp "a.txt") "1\n2\n3\n")
(spit (path/join tmp "b.txt") "x\ny\n")
(spit (path/join tmp "note.md") "skip\n")

(defn count-lines [p]
  (with [f (file/open p :rb)]
    (var n 0)
    (while (file/read f :line) (++ n))
    n))

(defn txt-total [dir]
  (var total 0)
  (each name (sort (os/dir dir))
    (when (= ".txt" (path/ext name))
      (def n (count-lines (path/join dir name)))
      (printf "%-8s %d" name n)
      (+= total n)))
  total)

(printf "%-8s %d" "TOTAL" (txt-total tmp))
(each name (os/dir tmp) (os/rm (path/join tmp name)))

# ---- 練習解答 ----
(print "== 練習解答 ==")

# 1. 不存在才寫
(defn ensure-file [p text]
  (if (os/stat p)
    false
    (do (spit p text) true)))

(def g (path/join tmp "hello.txt"))
(printf "第一次：%j" (ensure-file g "hi\n"))
(printf "第二次：%j" (ensure-file g "改掉\n"))
(printf "內容：%j" (slurp g))

# 2. 每個檔案的大小，跳過子目錄
(defn sizes [dir]
  (def out @{})
  (each name (os/dir dir)
    (def p (path/join dir name))
    (when (= :file (os/stat p :mode))
      (put out name (os/stat p :size))))
  out)

(os/mkdir (path/join tmp "sub"))
(spit (path/join tmp "big.txt") "0123456789")
(def t (sizes tmp))
(each k (sort (keys t)) (printf "%-10s %d" k (t k)))

(os/rm (path/join tmp "sub"))
(each name (os/dir tmp) (os/rm (path/join tmp name)))
(os/rm tmp)
(printf "清乾淨了：%j" (nil? (os/stat tmp)))
