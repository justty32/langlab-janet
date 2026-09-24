# 11-3 · todo 指令層

資料層已經會讀檔、存檔、新增、打勾、刪除，但使用者碰不到它。這課寫 `todo/cli.janet`：把使用者打的 `todo add 買牛奶` 翻譯成對資料層的呼叫，再把結果印給人看。寫完，`todo` 就真的能用了。

## 這是什麼、為什麼

指令層只做三件事：看懂使用者打了什麼、叫資料層做事、把結果或錯誤印出來。它不碰 JSON、不管檔案格式，那些是 11-2 的事。分開的好處是資料層可以單獨測試，指令層壞了也不會弄壞資料。

`todo` 有四個子命令（subcommand，接在程式名後面的第一個字，像 `git commit` 的 `commit`）：`add`、`list`、`done`、`rm`。每個子命令吃的參數不一樣，所以每個各寫一個函式。

每個函式最後都回傳一個 exit code（程式結束時交給作業系統的數字，0 代表成功，1 代表失敗）。回傳就好，不在裡面呼叫 `os/exit`。真正結束程式的是 `main.janet` 那一行 `(os/exit (cli/run ...))`。這樣測試時可以直接呼叫函式、看回傳值，程式不會半路被關掉。

## 動手

完成版在 `examples/course/11-todo/todo/cli.janet`，下面一段一段長出來。範例檔 `examples/course/11-3.janet` 把每一段都真的跑一次。

### 子命令：argparse 沒有，自己分派

8-3 學過的 `spork/argparse` 沒有內建子命令。做法很土但很好懂：看第一個字決定叫哪個函式，剩下的字交給那個函式，由它自己再跑一次 argparse。

關鍵是 argparse 的 `:args` 參數。8-3 用它餵假參數來示範；這裡拿它餵「子命令後面那些字」。它會把第 0 格當程式名跳過，所以要先墊一個名字在前面：

```janet
(import spork/argparse :as ap)
(def args @["a" "b" "-f" "p.json"])   # 使用者在 add 後面打的字
(def full [(string "todo " "add") ;args])
(get full 0)   # => "todo add"
(length full)  # => 5
(def r (ap/argparse "x" :args full
                    "file" {:kind :option :short "f"}
                    :default {:kind :accumulate}))
(r "file")     # => "p.json"
(r :default)   # => @["a" "b"]
```

`;args` 前面那個分號叫 splice（攤開）：把陣列的每一格拆出來、一格一格放進外面這個 tuple，所以 `full` 是五格，不是「一個名字加一整個陣列」兩格。10-4 提過，Janet 的 `;` 不是註解，就是這個。墊的名字寫 `"todo add"`，argparse 印 `--help` 時第一行就會是 `usage: todo add ...`，使用者看得懂是哪個子命令的說明。

### parse：每個子命令都要的那幾行

每個子命令都要吃 `--file`（指定資料檔在哪）。與其寫四次，不如抽出來：

```janet
(def file-opt
  {:kind :option :short "f"
   :help "資料檔路徑（預設看環境變數 TODO_FILE，再不然就是 ./todo.json）"})

(defn- parse [name desc args & specs]
  (ap/argparse desc :args [(string "todo " name) ;args] "file" file-opt ;specs))
```

`defn-` 是只有這個檔自己用得到的函式（6-1b 講過），外面 `import` 看不到。`& specs` 收下「這個子命令自己多要的選項」，再用 `;specs` 攤回去接在 `"file" file-opt` 後面。於是每個子命令只要寫自己獨有的那部分。

`parse` 解析成功回傳一張 table；使用者打了 `--help` 或打錯選項時，argparse 自己印完說明，回傳 nil。

### with-db：讀、做、存

`add`、`done`、`rm` 都是同一個節奏：讀資料檔、改一下、存回去。把頭尾兩步包起來，中間那步用函式傳進來：

```janet
(defn- with-db [res f]
  (def path (store/data-path (res "file")))
  (def db (store/load path))
  (def code (f db))
  (store/save path db)
  code)
```

`(res "file")` 是使用者給的 `--file`，沒給就是 nil，`store/data-path` 會接著看環境變數、再退回 `todo.json`（11-2 寫的）。`f` 拿到讀好的資料，回傳 exit code；`with-db` 存完檔，把那個 code 原樣交回去。

### cmd-add：第一個子命令

```janet
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
```

一行一行看：

`:default {:kind :accumulate}` 收下所有不帶 `-` 的字。`todo add 寫 Janet 作業` 會收到 `@["寫" "Janet" "作業"]`，`string/join` 用空白接回一句。

`(unless res (break 1))`：`res` 是 nil 代表 argparse 已經印過說明或錯誤了，這裡什麼都不用補，直接回 1。函式裡的 `break` 就是別的語言的 `return`，5-3 講過。

使用者什麼都沒給時，`(res :default)` 是 nil，`(or ... @[])` 換成空陣列，接出來是空字串：

```janet
(string/join @[] " ")  # => ""
(empty? "")            # => true
(print (string/join @["寫" "Janet" "作業"] " "))
# 印出：寫 Janet 作業
```

空的就用 `eprint` 印一句用法、回 1。`eprint` 跟 `print` 一樣，只是印到 stderr（錯誤輸出），下一篇講為什麼。

有內容才進 `with-db`。傳進去的 `(fn [db] ...)` 就是「中間那一步」：新增一筆、印出來、回 0。

後面三個子命令與總入口 `run` 在續篇：[11-3b · todo 指令層（續）](11-3b-todo-指令層.md)
