# 配合 course/11-4-todo-測試與打包.md：指令層的測試。
# 直接呼叫 cli/run（不開子行程），用 --file 指到暫存檔，看 exit code 與印出來的字。
(import spork/test)
(import ../todo/cli)
(import ../todo/store)
(import ./helper)

(def dir (helper/temp-dir "cli"))
(defer (helper/cleanup dir)
  (def path (string dir "/todo.json"))

  (defn run
    "跑一次 todo 指令，回傳 [exit-code 印出來的字]。"
    [& args]
    (def [code out] (test/capture-stdout
                      (test/suppress-stderr (cli/run @[;args "--file" path]))))
    [code (string out)])

  # 沒給子命令、未知子命令都是 1
  (assert (= 1 (first (run))) "沒子命令 → 1")
  (assert (= 1 (first (run "nope"))) "未知子命令 → 1")

  # add 之後檔案真的有東西
  (def [c1 o1] (run "add" "買" "牛奶"))
  (assert (= 0 c1) "add 成功 → 0")
  (assert (= "新增 #1：買 牛奶\n" o1) "add 印出新增那筆，多個字用空白接")
  (assert (= 1 (length ((store/load path) :items))) "add 之後檔案裡有一筆")

  # list 只列沒做完的；--all 全列
  (run "add" "倒垃圾")
  (assert (= 0 (first (run "done" "1"))) "done 1 → 0")
  (assert (= "[ ] 2  倒垃圾\n" (last (run "list"))) "list 預設藏掉做完的")
  (assert (= "[x] 1  買 牛奶\n[ ] 2  倒垃圾\n" (last (run "list" "--all"))) "--all 全列")

  # 錯的 id：非數字、不存在，都回 1、都不改檔案
  (assert (= 1 (first (run "done" "abc"))) "done abc → 1")
  (assert (= 1 (first (run "rm" "99"))) "rm 99 → 1")
  (assert (= 2 (length ((store/load path) :items))) "失敗的指令不動資料")

  # rm 之後 list 少一筆
  (assert (= 0 (first (run "rm" "2"))) "rm 2 → 0")
  (assert (= "（沒有事情）\n" (last (run "list"))) "剩下的都做完了")

  # 資料檔壞掉：run 要接住錯誤回 1，不能整個炸出 stack trace
  (spit path "{oops")
  (def [c2 _] (run "list"))
  (assert (= 1 c2) "壞檔 → 1"))

(print "cli 測試通過 ✓")
