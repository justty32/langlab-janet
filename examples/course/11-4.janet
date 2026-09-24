# 配合 course/11-4-todo-測試與打包.md（與續篇 11-4b、11-4c）
# 示範測試用的幾樣工具；資料檔一律放暫存目錄，跑完刪掉，不碰 repo。
(import spork/test)
(import ./11-todo/todo/store)

(defn temp-dir
  "跟 11-todo/test/helper.janet 同一招：在 $TMPDIR（沒有就 /tmp）底下開一個目錄。"
  [tag]
  (def dir (string (os/getenv "TMPDIR" "/tmp") "/course-11-4-" tag "-" (os/time)
                   "-" (math/floor (* 1000 (math/random)))))
  (os/mkdir dir)
  dir)

(defn cleanup [dir]
  (each name (os/dir dir) (os/rm (string dir "/" name)))
  (os/rm dir))

(print "== capture-stdout：回 [回傳值 印出來的字] ==")
(def [v out] (test/capture-stdout (do (print "hi") 42)))
(printf "回傳值 %j，印出來的字 %j" v out)
# 印出：回傳值 42，印出來的字 "hi\n"

(print "== suppress-stderr：錯誤訊息吞掉，回傳值照拿 ==")
(def code (test/suppress-stderr (eprint "這行不會出現") 1))
(print "拿到的回傳值：" code)

(print "== defer：中途拋錯也會清掉暫存目錄 ==")
(var kept nil)
(def [ok e]
  (protect
    (let [dir (temp-dir "defer")]
      (set kept dir)
      (defer (cleanup dir)
        (spit (string dir "/x.txt") "hello")
        (error "測試中途爆了")))))
(print "protect 接到：" ok " " e)
(print "目錄還在嗎？" (if (os/stat kept) "還在" "已經清掉"))
# 印出：目錄還在嗎？已經清掉

(print "== 對暫存檔做一次 round-trip ==")
(def dir (temp-dir "rt"))
(defer (cleanup dir)
  (def path (string dir "/todo.json"))
  (def db (store/load path))
  (store/add db "買牛奶")
  (store/add db "寫 Janet 作業")
  (store/save path db)
  (def back (store/load path))
  (assert (deep= back db) "round-trip 之後要一樣")
  (print "round-trip 通過，讀回來第二筆是：" (get-in back [:items 1 :text])))

# ---- 練習解答 ----
(print "== 練習解答 ==")
(import ./11-todo/todo/cli)

# 第 1 題：list --all 要把做完的也列出來
(def d1 (temp-dir "ex1"))
(defer (cleanup d1)
  (def p (string d1 "/todo.json"))
  (defn run [& args]
    (def [c o] (test/capture-stdout
                 (test/suppress-stderr (cli/run @[;args "--file" p]))))
    [c (string o)])
  (run "add" "甲")
  (run "add" "乙")
  (run "done" "1")
  (assert (= "[ ] 2  乙\n" (last (run "list"))) "list 只列沒做完的")
  (assert (= "[x] 1  甲\n[ ] 2  乙\n" (last (run "list" "--all"))) "--all 全列")
  (assert (= "[x] 1  甲\n[ ] 2  乙\n" (last (run "list" "-a"))) "-a 也一樣")
  (print "第 1 題通過"))

# 第 2 題：rm 之後 next-id 不會倒退，新的一筆不會撞號
(def db2 (store/empty-db))
(store/add db2 "一")
(store/add db2 "二")
(store/rm db2 2)
(assert (= 3 (db2 :next-id)) "rm 不改 next-id")
(assert (= 3 ((store/add db2 "三") :id)) "新的一筆拿 3，不是 2")
(print "第 2 題通過")

# 第 3 題：用 err-of 的寫法檢查「形狀不對」的訊息也帶路徑
(def d3 (temp-dir "ex3"))
(defer (cleanup d3)
  (def p (string d3 "/todo.json"))
  (spit p "[1, 2]")
  (def [ok3 e3] (protect (store/load p)))
  (assert (not ok3) "壞檔一定要失敗")
  (assert (string/find p e3) "形狀不對的訊息也要帶路徑")
  (print "第 3 題通過"))
