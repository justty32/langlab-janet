# 配合 course/11-2-todo-資料層.md：todo 的資料層。
# 只管「資料長什麼樣、存在哪、怎麼讀寫」，完全不碰命令列、不 print。
#
# 資料檔（JSON）長這樣：
#   {"next-id": 3, "items": [{"id": 1, "text": "買牛奶", "done": false}, ...]}
(import spork/json)

(defn data-path
  ``決定資料檔在哪：參數 > 環境變數 TODO_FILE > 目前目錄的 todo.json。
  ⚠ 放在函式裡才會「每次執行時」讀環境變數；寫在頂層會被 jpm build 凍住（見 11-4）。``
  [&opt override]
  (or override (os/getenv "TODO_FILE") "todo.json"))

(defn empty-db
  "一份全新的、空的資料。"
  []
  @{:next-id 1 :items @[]})

(defn- check-shape
  "壞掉的檔案不一定是 JSON 語法錯，也可能形狀不對；這裡把兩種都擋下來。"
  [db path]
  (unless (and (table? db) (number? (db :next-id)) (array? (db :items)))
    (errorf "資料檔 %s 的內容不是 todo 的格式（少了 next-id 或 items）" path))
  db)

(defn load
  ``讀資料檔。檔案不存在就回一份空的（第一次用不用先建檔）；
  檔案在但內容壞掉就拋錯，錯誤訊息裡有路徑，讓使用者知道該去修哪個檔。``
  [path]
  (if (nil? (os/stat path))
    (empty-db)
    (let [raw (slurp path)
          [ok db] (protect (json/decode raw true))]
      (unless ok
        (errorf "資料檔 %s 不是合法的 JSON：%s" path db))
      (check-shape db path))))

(defn save
  "把整份資料寫回檔案（縮排過，人打開也看得懂）。"
  [path db]
  (spit path (json/encode db "  " "\n")))

(defn add
  "新增一件事，回傳新的那一筆。id 從 next-id 拿，拿完加一。"
  [db text]
  (def item @{:id (db :next-id) :text text :done false})
  (array/push (db :items) item)
  (update db :next-id inc)
  item)

(defn find-item
  "照 id 找一筆，找不到回 nil。"
  [db id]
  (find |(= id ($ :id)) (db :items)))

(defn done
  "把某筆標成完成。回傳那一筆；id 不存在回 nil。"
  [db id]
  (when-let [item (find-item db id)]
    (put item :done true)))

(defn rm
  "刪掉某筆。回傳被刪的那一筆；id 不存在回 nil。"
  [db id]
  (when-let [item (find-item db id)]
    (put db :items (filter |(not= id ($ :id)) (db :items)))
    item))
