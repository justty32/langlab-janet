# 配合 course/11-4-todo-測試與打包.md：資料層的測試。
# 不碰命令列、不看輸出，只驗「資料進去、出來、存檔、讀回」對不對。
(import ../todo/store)
(import ./helper)

(def dir (helper/temp-dir "store"))
(defer (helper/cleanup dir)
  (def path (string dir "/todo.json"))

  # 檔案不存在 → 空資料，而且不會順手建檔
  (def db (store/load path))
  (assert (deep= db @{:next-id 1 :items @[]}) "不存在的檔應該給一份空資料")
  (assert (nil? (os/stat path)) "load 不該自己建檔")

  # add 拿到遞增的 id
  (def a (store/add db "買牛奶"))
  (def b (store/add db "倒垃圾"))
  (assert (= 1 (a :id)) "第一筆 id 是 1")
  (assert (= 2 (b :id)) "第二筆 id 是 2")
  (assert (= 3 (db :next-id)) "next-id 要跟著往前")

  # 存了再讀回來要一模一樣（連中文都要活著回來）
  (store/save path db)
  (def back (store/load path))
  (assert (deep= back db) "round-trip 之後資料要一樣")
  (assert (= "買牛奶" (get-in back [:items 0 :text])) "中文要能讀回來")

  # done／rm 對存在與不存在的 id
  (assert (store/done back 1) "done 存在的 id 回那一筆")
  (assert (get-in back [:items 0 :done]) "done 之後旗標要是 true")
  (assert (nil? (store/done back 99)) "done 不存在的 id 回 nil")
  (assert (= "倒垃圾" ((store/rm back 2) :text)) "rm 回被刪的那筆")
  (assert (= 1 (length (back :items))) "rm 之後少一筆")
  (assert (nil? (store/rm back 2)) "再 rm 一次回 nil")

  # 壞檔：JSON 語法錯、形狀不對，訊息都要帶路徑
  (spit path "{oops")
  (def msg1 (helper/err-of |(store/load path)))
  (assert (string/find path msg1) "語法錯的訊息要帶路徑")
  (assert (string/find "不是合法的 JSON" msg1) "語法錯要講明是 JSON 壞了")
  (spit path "[1, 2, 3]")
  (def msg2 (helper/err-of |(store/load path)))
  (assert (string/find "不是 todo 的格式" msg2) "形狀不對要講明")

  # data-path 的三層優先順序
  (assert (= "/x/y.json" (store/data-path "/x/y.json")) "有給參數就用參數")
  (os/setenv "TODO_FILE" "/env/z.json")
  (assert (= "/env/z.json" (store/data-path)) "沒給參數就看環境變數")
  (os/setenv "TODO_FILE" nil)
  (assert (= "todo.json" (store/data-path)) "都沒有就是 todo.json"))

(print "store 測試通過 ✓")
