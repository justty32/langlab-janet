# 11-1 · todo：規劃與骨架

前十個單元學的都是零件。這個單元把零件組起來，從頭做一個真的能用的小工具：命令列上的待辦清單 `todo`。這課先不寫細節，只做兩件事：想清楚程式要拆成哪幾塊，再把檔案骨架搭好、讓它能跑。

## 這是什麼、為什麼

我們要做的東西用起來長這樣。資料存在一個 JSON 檔裡，關掉再開也還在：

```sh
janet main.janet add 買牛奶        # 新增 #1：買牛奶
janet main.janet add 寫 Janet 作業  # 新增 #2：寫 Janet 作業
janet main.janet add 倒垃圾        # 新增 #3：倒垃圾
janet main.janet list
# [ ] 1  買牛奶
# [ ] 2  寫 Janet 作業
# [ ] 3  倒垃圾
janet main.janet done 2            # 完成 #2：寫 Janet 作業
janet main.janet rm 3              # 刪除 #3：倒垃圾
janet main.janet list --all
# [ ] 1  買牛奶
# [x] 2  寫 Janet 作業
```

打錯也會好好講人話，並回傳 exit code 1（程式結束時交給 shell 的數字，0 代表成功）：

```sh
janet main.janet done 9     # 找不到 #9
janet main.janet done abc   # done：要給一個正整數 id，例：todo done 2
janet main.janet            # 用法：todo <add|list|done|rm> [參數] [--file 路徑]
                            # 每個子命令都有 --help，例：todo add --help
```

完成版已經放在 `examples/course/11-todo/`，你可以先進去玩玩。接下來四課會一支檔一支檔讀懂它。

### 先拆成兩層

動手寫之前，先決定「誰負責什麼」。這支工具拆成兩層：

- 資料層（`todo/store.janet`）：資料長什麼樣、存在哪、怎麼讀寫、怎麼新增刪除。它完全不碰命令列，也不 print 任何東西，只收值、回值。
- 指令層（`todo/cli.janet`）：把使用者打的 `add 買牛奶` 翻成「呼叫資料層的 add」，再把結果印成人看得懂的句子。錯誤訊息也是它印的。

為什麼要這樣拆？一個比喻：資料層是倉庫，指令層是櫃台。客人只跟櫃台講話，櫃台再去倉庫拿東西。這樣有三個好處：

1. 測試好寫。測資料層只要呼叫函式、看回傳值，不用去攔截螢幕上印了什麼。
2. 改輸出不會動到資料。想把 `[x]` 改成 `✓`，只改櫃台，倉庫的程式一行都不用碰。
3. 想換存法只改一層。哪天不想用 JSON 改用 SQLite，只改倉庫，櫃台照舊。

比喻不準的地方：真的倉庫和櫃台是兩個人同時在做事，這裡只是兩支檔，程式照順序一行一行跑，沒有「同時」。

## 動手

### 資料長什麼樣

整份資料是一個 table（可以改的鍵值對，3-1 教過）：

```janet
(def db @{:next-id 3
          :items @[@{:id 1 :text "milk" :done false}
                   @{:id 2 :text "homework" :done true}]})
(length (db :items))            # => 2
(get-in db [:items 1 :done])    # => true
(db :next-id)                   # => 3
```

`:items` 是一個 array，裡面每件事是一個小 table，有號碼 `:id`、內容 `:text`、做完沒 `:done`。例子用英文只是因為 `# =>` 比對不收中文，真的資料放中文沒問題。

為什麼要多存一個 `:next-id`，不直接拿「目前有幾筆＋1」當新號碼？因為會刪。假設有 #1、#2、#3，你刪了 #3，剩兩筆。若用「筆數＋1」，下一筆又會拿到 3。你記得 #3 是「倒垃圾」，結果 `done 3` 勾掉的卻是新的那件事。所以號碼用一個只會往上加的計數器發，發出去的號碼永遠不回收。

存到檔案裡的樣子就是 4-3 教過的 JSON，縮排過，打開來人也看得懂：

```sh
cat todo.json   # add 三筆、done 2、rm 3 之後
# {
#   "next-id": 4,
#   "items": [
#     {
#       "id": 1,
#       "done": false,
#       "text": "\u8CB7\u725B\u5976"
#     },
#     ...（#2 那筆同樣的形狀，"done": true）
```

`next-id` 是 4 不是 3：#3 雖然刪了，那個號碼已經發出去了。中文變成 `\u8CB7` 這種樣子是合法的 JSON 寫法，讀回來還是「買牛奶」。

骨架怎麼搭在續篇：[11-1b · todo 的骨架](11-1b-todo-骨架.md)
