# 配合 course/11-2-todo-資料層.md（續篇 11-2b-todo-資料層.md）
(import spork/json)
(import ./11-todo/todo/store)

(def dir (string (os/getenv "TMPDIR" "/tmp") "/janet-course-11-2"))
(os/mkdir dir)
(def path (string dir "/todo.json"))
(when (os/stat path) (os/rm path))

(print "== empty-db 與 data-path ==")
(printf "%j" (store/empty-db))
(printf "給參數：%j" (store/data-path "/x/y.json"))
(os/setenv "TODO_FILE" "/env/z.json")
(printf "看環境變數：%j" (store/data-path))
(os/setenv "TODO_FILE" nil)
(printf "都沒有：%j" (store/data-path))

(print "== save：中文被逃逸 ==")
(print (json/encode {:t "買"}))
(print (get (json/decode (json/encode {:t "買"}) true) :t))

(print "== load：檔案不存在 ==")
(def db (store/load path))
(printf "%j" db)
(printf "load 之後檔案在不在：%j" (os/stat path))

(print "== add／find-item／done／rm ==")
(def a (store/add db "買牛奶"))
(store/add db "寫 Janet 作業")
(store/add db "倒垃圾")
(printf "第一筆 id：%j，next-id：%j" (a :id) (db :next-id))
(print "找 #2：" ((store/find-item db 2) :text))
(printf "找 #9：%j" (store/find-item db 9))
(printf "done 2 回：%j" ((store/done db 2) :done))
(printf "done 9 回：%j" (store/done db 9))
(print "rm 3 回：" ((store/rm db 3) :text))
(printf "rm 3 再一次：%j" (store/rm db 3))
(printf "剩幾筆：%j" (length (db :items)))

(print "== round-trip：save 再 load ==")
(store/save path db)
(print (slurp path))
(def back (store/load path))
(printf "讀回來一樣嗎：%j" (deep= back db))
(print "第一筆：" (get-in back [:items 0 :text]))

(print "== 忘了給 true ==")
(def raw-db (json/decode (slurp path)))
(printf "%j" (get raw-db :next-id))
(printf "%j" (get raw-db "next-id"))

(print "== 壞檔 ==")
(spit path "{oops")
(print ((protect (store/load path)) 1))
(spit path "[1,2]")
(print ((protect (store/load path)) 1))

(os/rm path)
(os/rmdir dir)

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. pending-count：還沒完成的有幾筆
(defn pending-count [db]
  (length (filter |(not ($ :done)) (db :items))))
(def db2 (store/empty-db))
(store/add db2 "甲")
(store/add db2 "乙")
(store/done db2 1)
(printf "pending-count：%j" (pending-count db2))

# 2. undone：把某筆標回未完成，找不到回 nil（照 done 的樣子寫）
(defn undone [db id]
  (when-let [item (store/find-item db id)]
    (put item :done false)))
(printf "undone 1：%j" ((undone db2 1) :done))
(printf "undone 9：%j" (undone db2 9))

# 3. rename：改某筆的文字，回傳那一筆
(defn rename [db id text]
  (when-let [item (store/find-item db id)]
    (put item :text text)))
(print "rename 2：" ((rename db2 2 "丙") :text))
