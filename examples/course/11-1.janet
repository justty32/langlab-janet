# 配合 course/11-1-todo-規劃與骨架.md
# 跑法：janet examples/course/11-1.janet（不需要參數，不會寫進 repo）
(import ./11-todo/todo/cli)
(import ./11-todo/todo/store)  # 只在練習解答用到

(print "== 資料長什麼樣 ==")
# 整份資料是一個 table：下一個要發的號碼＋一串事情
# （pp 會把中文逃逸成 \xE8…，所以這裡用英文內容，2-2 講過）
(def db @{:next-id 4
          :items @[@{:id 1 :text "milk" :done false}
                   @{:id 2 :text "homework" :done true}]})
(pp db)
(print "第一件事：" (get-in db [:items 0 :text]))
(print "下一個號碼：" (db :next-id))

(print "== argv 的第 0 個是程式名 ==")
# 假裝使用者打了 janet main.janet add milk，main 收到的就是這個
(def argv @["main.janet" "add" "milk"])
(pp (array/slice argv 1))

(print "== 骨架接起來了 ==")
# 資料檔放暫存目錄，跑完刪掉
(def tmp-dir (string (os/getenv "TMPDIR" "/tmp") "/course-11-1-" (os/getpid)))
(os/mkdir tmp-dir)
(def tmp (string tmp-dir "/todo.json"))
(flush) # 先把 stdout 送出去，免得跟 stderr 的字交錯
(def code (cli/run @["list" "--file" tmp]))
(print "cli/run 回傳的 exit code：" code)
(flush)
(def code2 (cli/run @[]))  # 用法會印到 stderr
(print "什麼都不給，回傳：" code2)
(os/rm tmp)
(os/rmdir tmp-dir)

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. #2、#3 都刪掉，next-id 還是 4（發出去的號碼不回收）；新增的那筆拿到 4
#    用資料層的 add／rm 實際走一遍（只動記憶體裡的 table，不寫檔）
(def ex (store/empty-db))
(each t ["a" "b" "c"] (store/add ex t))
(store/rm ex 2)
(store/rm ex 3)
(print "刪完兩筆後 next-id：" (ex :next-id))
(print "新的一筆拿到 #" ((store/add ex "d") :id))
# 2. 只剩程式名，切完是空陣列；cli/run 印用法到 stderr，回傳 1
(pp (array/slice @["main.janet"] 1))
(flush)
(print "cli/run 回傳：" (cli/run (array/slice @["main.janet"] 1)))
# 3. store.janet 在 cli.janet 的上一層，要寫 (import ../store)
#    （../ 一樣是相對於 cli.janet 自己所在的 todo/ 資料夾）
