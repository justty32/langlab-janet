# 11-2b · todo 資料層（改資料與存讀一圈）

接續 [11-2](11-2-todo-資料層.md)。能讀能存了，接著寫改資料的四個函式：`add`、`find-item`、`done`、`rm`，最後把整條路走一圈，證明存進去的東西讀得回來。

## 這是什麼、為什麼

這四個函式都只改記憶體裡的 table，不碰檔案。什麼時候存檔是指令層（11-3）的事：讀進來、改、存回去。分開的好處是改資料的邏輯不用管檔案在哪。

它們共用一個回傳值的約定：做成功就回「那一筆」，找不到就回 nil。呼叫的人只要看回傳值是不是 nil，就知道該印「完成 #2」還是「找不到 #9」。

## 動手：add

```janet
(defn add [db text]
  (def item @{:id (db :next-id) :text text :done false})
  (array/push (db :items) item)
  (update db :next-id inc)
  item)
```

新的一筆拿 `:next-id` 當 id，`array/push`（3-2）塞到 `:items` 尾巴，再用 `update` 把 `:next-id` 加一。`update` 的意思是「拿出舊值、丟進函式、把結果放回去」：

```janet
(def db @{:next-id 1})
(update db :next-id inc)   # => @{:next-id 2}
```

為什麼不用「目前最大的 id 加一」？因為刪掉最後一筆之後，新的那筆會拿到舊 id，使用者會以為是同一件事。`:next-id` 只往前走，刪掉的 id 不會再出現。最後一行寫 `item`，讓函式回傳新的那一筆（5-3：最後一個值就是回傳值）。

## 動手：find-item 與 done

```janet
(defn find-item [db id]
  (find |(= id ($ :id)) (db :items)))

(defn done [db id]
  (when-let [item (find-item db id)]
    (put item :done true)))
```

`find` 從頭找第一個讓條件成立的元素，找不到回 nil。`|(...)` 是 6-2 的簡寫函式，`$` 是傳進來的那一筆：

```janet
(def items @[@{:id 1} @{:id 2}])
(find |(= 2 ($ :id)) items)   # => @{:id 2}
(find |(= 9 ($ :id)) items)   # => nil
```

`when-let` 是「先綁定，值是真的才往下做，不然整個回 nil」。找不到時 `done` 自動回 nil，不用自己寫 `if`：

```janet
(when-let [x (find |(= 2 $) [1 2])] (* x 10))   # => 20
(when-let [x (find |(= 9 $) [1 2])] (* x 10))   # => nil
```

`put` 回傳被改的那個 table，所以 `done` 找到時回的就是那一筆。

## 動手：rm

```janet
(defn rm [db id]
  (when-let [item (find-item db id)]
    (put db :items (filter |(not= id ($ :id)) (db :items)))
    item))
```

`filter` 留下 id 不等於要刪的那些，產生一個新的 array，再 `put` 回 `:items`。先找一次是為了能回傳被刪的那筆，讓指令層印「刪除 #3：倒垃圾」。

## 動手：存讀一圈

範例檔在暫存目錄走一遍 load → add → save → load：

```janet
(import ./11-todo/todo/store)       # path 是暫存目錄裡的檔
(def db (store/load path))          # 檔案還不存在，拿到空的
(store/add db "買牛奶")
(store/save path db)
(def back (store/load path))
(print (deep= back db))             # 印出：true
(print (get-in back [:items 0 :text]))   # 印出：買牛奶
(os/rm path)
```

`deep=`（3-3）比內容，table 用 `=` 比的是不是同一個東西，一定是 false。讀回來跟原本一樣、中文也還在，資料層就完成了。整段在範例檔裡跑：

```sh
$ janet examples/course/11-2.janet
# == round-trip：save 再 load ==
# ...
# 讀回來一樣嗎：true
# 第一筆：買牛奶
```

## 你會踩的坑

⚠ `rm` 之後，手上拿著的舊 `:items` 沒變。
你會以為先 `(def items (db :items))`，`rm` 之後 `items` 會少一筆。其實還是原本那麼多。因為 `filter` 產生新的 array 放回 db，舊的 array 沒被動過，你手上的還是它。要看最新的，每次都重新 `(db :items)`。

```janet
(def db @{:items @[@{:id 1} @{:id 2}]})
(def old (db :items))
(put db :items (filter |(not= 2 ($ :id)) (db :items)))
(length old)   # => 2
(length (db :items))   # => 1
```

## 小練習

1. 寫 `(pending-count db)`：回傳還沒完成的有幾筆。
2. 寫 `(undone db id)`：把某筆標回未完成，找不到回 nil，照 `done` 的樣子寫。
3. 寫 `(rename db id text)`：改某筆的文字，回傳那一筆。

解答在 `examples/course/11-2.janet` 最後，不用改專案的檔。

## 想更深

- [docs/03 JSON](../docs/03-json.md)：encode／decode 的其他參數、改巢狀值的招式。
- [docs/19 檔案與檔案系統](../docs/19-檔案與檔案系統.md)：`slurp`／`spit` 以外的讀寫方式、`os/stat` 能查什麼。
- [docs/20 錯誤處理與資源管理](../docs/20-錯誤處理與資源管理.md)：`protect`、`try`、`errorf` 的更多用法。

下一課：[11-3 · todo 指令層](11-3-todo-指令層.md)
