# 配合 course/11-3-todo-指令層.md（與續篇 11-3b、11-3c）
# 直接呼叫 cli/run（不經過 main.janet），印出每次回傳的 exit code。
# 資料檔放暫存目錄，跑完刪掉。錯誤訊息會印到 stderr，那是正常的。
(import spork/argparse :as ap)
(import ./11-todo/todo/cli)
(import ./11-todo/todo/store)

(def dir (string (os/getenv "TMPDIR" "/tmp") "/course-11-3-" (os/getpid)))
(os/mkdir dir)
(def p (string dir "/todo.json"))

(defn todo
  "模仿在終端機打 todo ...：印出指令、跑 cli/run、印 exit code。"
  [& words]
  (print "$ todo " (string/join words " "))
  (def code (cli/run @[;words "--file" p]))
  (print "  → exit " code))

(print "== 子命令：墊一個程式名給 argparse ==")
(def r (ap/argparse "x" :args ["todo add" "a" "b" "-f" "p.json"]
                    "file" {:kind :option :short "f"}
                    :default {:kind :accumulate}))
(printf "%j %j" (r "file") (r :default))

(print "== cmd-add ==")
(todo "add" "買牛奶")
(todo "add" "寫" "Janet" "作業")
(todo "add" "倒垃圾")
(todo "add")

(print "== cmd-list ==")
(todo "list")

(print "== parse-id 與 cmd-by-id ==")
(printf "%j %j %j" (scan-number "abc") (scan-number "2") (scan-number "2.5"))
(todo "done" "2")
(todo "list")
(todo "list" "--all")
(todo "rm" "3")
(print "資料檔現在長這樣：")
(print (slurp p))
(todo "done" "9")
(todo "done" "abc")

(print "== run：沒給子命令、打錯子命令 ==")
(print "$ todo") (print "  → exit " (cli/run @[]))
(print "$ todo foo") (print "  → exit " (cli/run @["foo"]))

(print "== 資料檔壞掉：protect 接成一行 ==")
(spit p "{oops")
(todo "list")

(os/rm p)

# ---- 練習解答 ----
(print "== 練習 1：count 子命令 ==")
(defn cmd-count
  "印出還沒做完幾件、全部幾件。"
  [args]
  (def res (ap/argparse "數一數" :args ["todo count" ;args]
                        "file" {:kind :option :short "f"}))
  (unless res (break 1))
  (def db (store/load (store/data-path (res "file"))))
  (def left (length (filter |(not ($ :done)) (db :items))))
  (printf "還沒做 %d 件，全部 %d 件" left (length (db :items)))
  0)

# 不改專案檔：拿 cli/commands 當底，自己多放一個 count
(def my-commands (merge cli/commands {"count" cmd-count}))
(defn my-run [args]
  (if-let [h (get my-commands (get args 0))]
    (h (array/slice args 1))
    (do (cli/usage) 1)))
(todo "add" "買牛奶")
(todo "add" "倒垃圾")
(todo "done" "1")
(print "  → exit " (my-run @["count" "--file" p]))

(print "== 練習 2：done 0 與 done 2.5 ==")
(todo "done" "0")     # 0 不是 pos?
(todo "done" "2.5")   # 2.5 不是 int?

(os/rm p)
(os/rmdir dir)
