# 11-1b · todo 的骨架

接續 [11-1 · todo：規劃與骨架](11-1-todo-規劃與骨架.md)。上半課決定了分兩層、資料長什麼樣，這半課把檔案擺好，讓它從 `main.janet` 一路接到資料層。

## 動手（續）

### 目錄長相

```text
examples/course/11-todo/
├── project.janet      專案說明書（9-2）
├── main.janet         進入點，只有七行
├── todo/
│   ├── store.janet    資料層（11-2 寫）
│   └── cli.janet      指令層（11-3 寫）
└── test/              測試（11-4 寫）
```

兩層各自一支檔，放在跟專案同名的 `todo/` 資料夾裡。`main.janet` 不放邏輯，所以它留在最外面。

### project.janet：三個宣告

9-2 講過 jpm 只認 `project.janet`。這個專案的三個宣告：

```janet
(declare-project
  :name "todo"
  :description "課程用的待辦命令列工具"
  :version "0.1.0"
  :dependencies ["spork"])

(declare-source
  :prefix "todo"
  :source ["todo/store.janet" "todo/cli.janet"])

(declare-executable
  :name "todo"
  :entry "main.janet"
  :install false)
```

`declare-project` 報名字，並說要用 spork（JSON 和 argparse 都在裡面）。`declare-source` 說「別人 `jpm install` 之後可以 import 的是這兩支檔」，這個專案平常用不到它。`declare-executable` 說「`jpm build` 時從 `main.janet` 開始，編出一個叫 `todo` 的執行檔」，11-4 會用到。

### main.janet：只做一件事

```janet
# 配合 course/11-1-todo-規劃與骨架.md：todo 的進入點，只做一件事：把參數交給指令層。
# 跑法：janet main.janet <add|list|done|rm> [參數] [--file 路徑]
(import ./todo/cli)

(defn main [& argv]
  # argv[0] 是程式自己的名字，從 [1] 起才是使用者打的
  (os/exit (cli/run (array/slice argv 1))))
```

整支就這七行。9-2 講過，檔案裡有叫 `main` 的函式，`janet main.janet …` 跑完頂層就會自動呼叫它，把命令列參數交進來。

`argv` 的第 0 個是程式自己的名字（`janet main.janet add 買牛奶` 時是 `"main.janet"`），使用者打的從第 1 個開始。`array/slice` 把它切掉：

```janet
(array/slice @["main.janet" "add" "milk"] 1)   # => @["add" "milk"]
(array/slice @["main.janet"] 1)                # => @[]
```

切好的參數交給 `cli/run`。它回傳一個數字當 exit code，`os/exit` 再把它交給 shell。main 自己不判斷任何事，全部交給指令層。

### 誰 import 誰

三支檔排成一條線，箭頭是「import 了誰」：

```text
main.janet  ──(import ./todo/cli)──▶  todo/cli.janet  ──(import ./store)──▶  todo/store.janet
```

注意兩行 import 的寫法不一樣。9-1 講過，`./` 是相對於「寫這行 import 的那支檔」所在的資料夾。`main.janet` 在最外面，所以要寫 `./todo/cli`；`cli.janet` 本身就在 `todo/` 裡，所以寫 `./store` 就找得到隔壁的 `store.janet`。

箭頭只往一個方向走：store 不 import cli，也不知道有命令列這回事。這就是上半課說的「倉庫不碰櫃台」落實在程式碼上的樣子。

### 骨架接起來了沒

範例檔 `examples/course/11-1.janet` 從外面 import 指令層，對一個暫存檔跑一次 `list`：

```sh
janet examples/course/11-1.janet
# == 骨架接起來了 ==
# （沒有事情）
# cli/run 回傳的 exit code：0
# 用法：todo <add|list|done|rm> [參數] [--file 路徑]
# 每個子命令都有 --help，例：todo add --help
# 什麼都不給，回傳：1
```

它直接呼叫 `(cli/run @["list" "--file" tmp])`，跟 main 做的事一樣，只是沒有 `os/exit`，所以能拿到回傳值印出來。這也預告了 11-4 的測試寫法：測指令層不必真的開一個行程，呼叫 `cli/run` 就好。

## 你會踩的坑

⚠ 子資料夾裡的 import 多寫一層

你會以為：import 路徑都從專案根目錄算，所以 `cli.janet` 裡也該寫 `(import ./todo/store)`。

其實是：它會去找 `todo/todo/store.janet`，跑起來直接失敗：

```text
error: could not find module ./todo/store:
    todo/todo/store.jimage
    todo/todo/store.janet
    ...
```

因為：`./` 相對於寫這行的檔。`cli.janet` 已經在 `todo/` 裡，再加一層就多了。錯誤訊息列出的那串路徑就是它實際找過的地方，看到路徑重複就知道是這個坑。

⚠ 在 main 裡忘了切掉 argv[0]

你會以為：`main` 收到的參數就是使用者打的那些，直接 `(cli/run argv)` 就好。

其實是：`janet main.janet list` 時 `argv` 是 `@["main.janet" "list"]`，指令層會把 `"main.janet"` 當成子命令，印出「未知子命令 "main.janet"」。

因為：Janet 照 C 的慣例，參數陣列的第 0 個放程式自己的名字。

## 小練習

1. 資料目前是 #1、#2、#3，`next-id` 是 4。把 #2 和 #3 都刪掉之後，`next-id` 是多少？再新增一筆會拿到幾號？
2. 使用者只打 `janet main.janet`，`(array/slice argv 1)` 會是什麼？`cli/run` 會回傳多少？
3. 如果把 `store.janet` 搬到專案最外面（跟 `main.janet` 並排），`cli.janet` 那行 import 要改成什麼？

答案在 `examples/course/11-1.janet` 最後。

## 想更深

- [docs/05 jpm 與專案](../docs/05-jpm-與專案.md)：`project.janet` 能寫的其他宣告、jpm 指令全表。
- [docs/05e import 與模組路徑](../docs/05e-import-與模組路徑.md)：import 實際去哪些地方找檔、`module/paths` 怎麼排順序。
- [docs/05b 建立新專案](../docs/05b-建立新專案.md)：`main` 什麼時候會被自動呼叫、什麼時候不會。

下一課：[11-2 · todo 資料層](11-2-todo-資料層.md)
