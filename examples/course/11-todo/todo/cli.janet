# 配合 course/11-3-todo-指令層.md：todo 的指令層。
# 把命令列參數翻譯成對資料層的呼叫，並負責印出結果與錯誤。
# 每個子命令一個函式，各自跑自己的 argparse；都回傳 exit code（0 成功、1 失敗）。
(import spork/argparse :as ap)
(import ./store)

# 每個子命令都吃的共用選項
(def file-opt
  {:kind :option :short "f"
   :help "資料檔路徑（預設看環境變數 TODO_FILE，再不然就是 ./todo.json）"})

(defn- parse
  "跑一次 argparse。回傳結果 table；解析失敗或 --help 時回 nil（usage 已經印過）。"
  [name desc args & specs]
  (ap/argparse desc :args [(string "todo " name) ;args] "file" file-opt ;specs))

(defn- with-db
  "讀資料檔 → 跑 f → 存回去。f 回傳 exit code。"
  [res f]
  (def path (store/data-path (res "file")))
  (def db (store/load path))
  (def code (f db))
  (store/save path db)
  code)

(defn- parse-id
  "位置參數的第一個要是正整數 id；不是就回 nil。"
  [res]
  (def s (get-in res [:default 0]))
  (def n (and s (scan-number s)))
  (when (and n (int? n) (pos? n)) n))

(defn cmd-add [args]
  (def res (parse "add" "新增一件事" args
                  :default {:kind :accumulate :help "<要做的事>，可以多個字"}))
  (unless res (break 1))
  (def text (string/join (or (res :default) @[]) " "))
  (when (empty? text)
    (eprint "add：要給內容，例：todo add 買牛奶")
    (break 1))
  (with-db res
    (fn [db]
      (def item (store/add db text))
      (printf "新增 #%d：%s" (item :id) (item :text))
      0)))

(defn cmd-list [args]
  (def res (parse "list" "列出全部" args
                  "all" {:kind :flag :short "a" :help "連做完的也列出來"}))
  (unless res (break 1))
  (with-db res
    (fn [db]
      (def items (if (res "all")
                   (db :items)
                   (filter |(not ($ :done)) (db :items))))
      (if (empty? items)
        (print "（沒有事情）")
        (each it items
          (printf "[%s] %d  %s" (if (it :done) "x" " ") (it :id) (it :text))))
      0)))

(defn- cmd-by-id
  "done 與 rm 長得一樣：拿一個 id，對資料層做一件事，印結果。"
  [name desc args action verb]
  (def res (parse name desc args :default {:kind :accumulate :help "<id>"}))
  (unless res (break 1))
  (def id (parse-id res))
  (unless id
    (eprintf "%s：要給一個正整數 id，例：todo %s 2" name name)
    (break 1))
  (with-db res
    (fn [db]
      (if-let [item (action db id)]
        (do (printf "%s #%d：%s" verb (item :id) (item :text)) 0)
        (do (eprintf "找不到 #%d" id) 1)))))

(defn cmd-done [args] (cmd-by-id "done" "標成完成" args store/done "完成"))
(defn cmd-rm   [args] (cmd-by-id "rm"   "刪掉一件事" args store/rm   "刪除"))

(def commands
  {"add" cmd-add "list" cmd-list "done" cmd-done "rm" cmd-rm})

(defn usage []
  (eprint "用法：todo <add|list|done|rm> [參數] [--file 路徑]")
  (eprint "每個子命令都有 --help，例：todo add --help"))

(defn run
  "整支工具的入口：args 是不含程式名的參數陣列，回傳 exit code。"
  [args]
  (def sub (get args 0))
  (def handler (get commands sub))
  (cond
    (nil? sub) (do (usage) 1)
    (nil? handler) (do (eprintf "未知子命令 %q" sub) (usage) 1)
    # 資料層拋出來的錯（檔案壞掉之類）在這裡統一接住，印成一行人話
    (let [[ok v] (protect (handler (array/slice args 1)))]
      (if ok v (do (eprint "錯誤：" v) 1)))))
