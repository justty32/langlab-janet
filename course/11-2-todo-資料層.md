# 11-2 · todo 資料層

11-1 把資料的形狀定好了：一個 table，裡面有 `:next-id` 跟 `:items`。這課把 `todo/store.janet` 一段一段寫出來：資料檔放哪、怎麼存、怎麼讀，還有檔案壞掉時怎麼辦。

## 這是什麼、為什麼

資料層就是專門管「資料長怎樣、存在哪、怎麼讀寫」的那一層。它不 print、不看命令列參數，只收資料、回資料。這樣做的好處是它可以單獨測：測試直接呼叫函式、看回傳值就好，不用去抓螢幕輸出（11-4 會用到）。

存檔格式選 JSON（4-3 教過）：人打開看得懂，壞了也能手修。整份資料一次讀進記憶體、改完一次寫回去，todo 這種小東西這樣最簡單。

整支檔一開頭只有一行 `(import spork/json)`，之後每一段都是一個 `defn`。範例檔 `examples/course/11-2.janet` 把這課跟續篇的每一段都跑一遍。

## 動手：空資料與檔案位置

先寫兩個最小的函式：

```janet
(defn data-path [&opt override]
  (or override (os/getenv "TODO_FILE") "todo.json"))

(defn empty-db []
  @{:next-id 1 :items @[]})
```

`empty-db` 每次呼叫都回一個新的 table，所以不同的地方拿到的不會互相影響。

`data-path` 決定資料檔在哪，順序是：有給參數就用參數，沒有就看環境變數 `TODO_FILE`，再沒有就是目前目錄的 `todo.json`。這裡靠的是 5-1 講過的 `or`：它回第一個真值，後面的不看。`os/getenv` 找不到變數時回 nil，自然就往後掉。

```janet
(or nil nil "todo.json")   # => "todo.json"
(or "/x.json" nil "todo.json")   # => "/x.json"
```

`os/getenv` 一定要放在函式裡，不要寫在檔案頂層。寫在頂層的話，打包成執行檔之後會被凍在打包那一刻的值，11-4 會實測給你看。

## 動手：存檔

```janet
(defn save [path db]
  (spit path (json/encode db "  " "\n")))
```

`json/encode` 後面兩個參數是「縮排用兩個空格、換行用 `\n`」，存出來的檔人打開也看得懂。`spit`（8-1）把整個檔換成新內容。存完的檔長這樣（中文變成 `\uXXXX`，下面的坑會講）：

```sh
{
  "next-id": 4,
  "items": [
    {
      "id": 1,
      "done": false,
      "text": "\u8CB7\u725B\u5976"
    },
```

## 動手：讀檔

讀檔要分三種情況處理。先看程式碼：

```janet
(defn- check-shape [db path]
  (unless (and (table? db) (number? (db :next-id)) (array? (db :items)))
    (errorf "資料檔 %s 的內容不是 todo 的格式（少了 next-id 或 items）" path))
  db)

(defn load [path]
  (if (nil? (os/stat path))
    (empty-db)
    (let [raw (slurp path)
          [ok db] (protect (json/decode raw true))]
      (unless ok
        (errorf "資料檔 %s 不是合法的 JSON：%s" path db))
      (check-shape db path))))
```

第一種：檔案不存在。`os/stat`（8-2）查不到東西就回 nil，這時回一份 `empty-db`。所以第一次用 todo 不必先建檔。`load` 也不會自己建檔，檔案要等第一次 `save` 才出現。

```janet
(os/stat "/absolutely/not/here")   # => nil
```

第二種：檔案在，但不是合法的 JSON。`json/decode` 會拋錯，我們用 7-1 的 `protect` 接住，拿到 `[false 錯誤訊息]`，再用 `errorf` 重新丟一個帶路徑的錯誤。原本的訊息只說第幾個字壞了，沒說是哪個檔。

```janet
(import spork/json)
(protect (json/decode "{oops" true))   # => (false "decode error at position 1: expected json string")
```

第三種：是合法的 JSON，但不是我們的格式，例如檔案裡是 `[1,2]`。`json/decode` 很開心地回 `@[1 2]`，不會報錯，所以要 `check-shape` 自己檢查：是 table、`:next-id` 是數字、`:items` 是 array，缺一個就拋錯。它最後回 `db`，讓 `load` 可以直接拿它當回傳值。

範例檔跑到壞檔那段會印出：

```sh
# 資料檔 /tmp/janet-course-11-2/todo.json 不是合法的 JSON：decode error at position 1: expected json string
# 資料檔 /tmp/janet-course-11-2/todo.json 的內容不是 todo 的格式（少了 next-id 或 items）
```

為什麼不存在就回空的，壞掉卻要拋錯？不存在是正常狀態，就是還沒用過。壞掉是使用者需要知道的事：他的資料還在檔案裡，只是讀不懂。

## 你會踩的坑

⚠ 壞檔也回空的，看起來比較友善。
你會以為讀不懂就給一份空資料，程式不會掛，使用者比較開心。其實下一次 `add` 完 `save`，整個檔會被新的空資料加一筆蓋掉，原本的待辦全部消失。因為 `save` 寫的是整份資料，不是只補新的那筆。拋錯讓程式停下來，使用者還有機會去修檔案。

⚠ 忘了給 `json/decode` 第二個參數 `true`。
你會以為 `(get db :next-id)` 拿得到值。其實拿到 nil，而且沒有錯誤。因為沒給 `true` 時鍵是字串 `"next-id"`，不是 keyword `:next-id`。我們的 `check-shape` 剛好會把這種情況攔下來，變成「不是 todo 的格式」。

```janet
(import spork/json)
(get (json/decode "{\"next-id\":1}") :next-id)   # => nil
(get (json/decode "{\"next-id\":1}" true) :next-id)   # => 1
```

⚠ 存出來的中文變成 `\u8CB7`。
你會以為檔案壞了或編碼錯了。其實這是合法的 JSON，讀回來還是中文。因為 spork/json 把所有非 ASCII 的字都寫成 `\uXXXX`（4-3 講過）。要確認內容，解回來看：

```janet
(import spork/json)
(print (json/encode {:t "買"}))
# 印出：{"t":"\u8CB7"}
(print (get (json/decode (json/encode {:t "買"}) true) :t))
# 印出：買
```

續篇：[11-2b · todo 資料層（改資料與存讀一圈）](11-2b-todo-資料層.md)
