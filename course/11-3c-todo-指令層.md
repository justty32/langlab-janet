# 11-3c · todo 指令層跑起來

接續 [11-3b · todo 指令層（續）](11-3b-todo-指令層.md)。指令層寫完了，這篇從終端機真的跑一遍，再看幾個容易踩到的地方。

## 動手（續）

### 從頭跑一輪

以下都在 `examples/course/11-todo/` 裡跑，環境變數 `TODO_FILE` 指到一個還不存在的暫存檔，所以不會在專案目錄留下 `todo.json`：

```sh
$ janet main.janet list
（沒有事情）
$ janet main.janet add 買牛奶
新增 #1：買牛奶
$ janet main.janet add 寫 Janet 作業
新增 #2：寫 Janet 作業
$ janet main.janet add 倒垃圾
新增 #3：倒垃圾
$ janet main.janet done 2
完成 #2：寫 Janet 作業
$ janet main.janet list
[ ] 1  買牛奶
[ ] 3  倒垃圾
$ janet main.janet list --all
[ ] 1  買牛奶
[x] 2  寫 Janet 作業
[ ] 3  倒垃圾
$ janet main.janet rm 3
刪除 #3：倒垃圾
```

檔案還不存在時 `list` 也不會炸，因為 11-2 的 `store/load` 遇到沒檔案就回一份空的。`寫 Janet 作業` 三個字被 `:accumulate` 收成三格，再被 `string/join` 接回一句。

### 出錯的時候

```sh
$ janet main.janet done 9
找不到 #9                                   # exit 1
$ janet main.janet done abc
done：要給一個正整數 id，例：todo done 2    # exit 1
$ janet main.janet add
add：要給內容，例：todo add 買牛奶          # exit 1
$ janet main.janet foo
未知子命令 "foo"
用法：todo <add|list|done|rm> [參數] [--file 路徑]
每個子命令都有 --help，例：todo add --help  # exit 1
$ echo '{oops' > $TODO_FILE; janet main.janet list
錯誤：資料檔 /tmp/…/t1.json 不是合法的 JSON：decode error at position 1: expected json string
```

最後一個是資料層拋的錯，被 `run` 裡的 `protect` 接住，只剩一行，沒有 stack trace。

### --file 與 --help

```sh
$ janet main.janet add 用參數指定 --file /tmp/…/t2.json
新增 #1：用參數指定
$ janet main.janet add --help
usage: todo add [option] ...

新增一件事

 Optional:
 -f, --file VALUE                            資料檔路徑（預設看環境變數 TODO_FILE，再不然就是 ./todo.json）
 -h, --help                                  Show this help message.
```

`--file` 放在內容前面或後面都可以，argparse 會把它挑出來，剩下的才進 `:default`。`usage: todo add` 那個名字，就是 `parse` 墊在第 0 格的 `"todo add"`。

## 你會踩的坑

### ⚠ --help 的 exit code 是 1

你會以為：`todo add --help` 是正常用法，應該回 0。其實是：它印完說明，exit code 是 1。因為 argparse 碰到 `--help` 和碰到打錯的選項都一樣回 nil，`(unless res (break 1))` 分不出這兩種。要分的話得自己先檢查參數裡有沒有 `--help` 或 `-h`，這個專案沒做。

### ⚠ argparse 的錯誤訊息印在 stdout

你會以為：打錯選項時的 `usage error: unknown option bogus` 跟我們的錯誤一樣走 stderr。其實是：它和整段 usage 都印在 stdout，`todo list --bogus > out.txt` 會把錯誤寫進 `out.txt`。因為 spork/argparse 內部用的是 `print`，不是 `eprint`。exit code 還是 1，腳本要判斷成敗請看 exit code，別看有沒有輸出。

### ⚠ protect 連你自己的 bug 也吞掉

你會以為：`run` 裡的 `protect` 只接資料層的壞檔錯誤。其實是：子命令裡任何執行期錯誤都會被接住，例如把 `%d` 寫給一個字串，只會看到一行 `錯誤：can not convert string "x" to 64 bit signed integer`，看不到是哪一行。因為 `protect` 不挑錯誤種類，而且把 stack trace 丟掉了。開發時想看完整 trace，就在 REPL 裡直接呼叫 `cli/cmd-add` 這些函式，不要經過 `run`。

### ⚠ cond 最後那條沒有條件

你會以為：`cond` 的「其他情況」要寫 `true` 或 `:else` 當條件。其實是：`run` 最後那個 `(let ...)` 單獨一個，就是其他情況。因為 `cond` 兩個兩個一組讀（條件、結果），最後落單的那一個直接當預設值。寫 `true (let ...)` 也對，只是多兩個字。

## 小練習

1. 不改專案檔，加一個 `count` 子命令：印出「還沒做 N 件，全部 M 件」。寫一個 `cmd-count` 函式（`parse` 和 `with-db` 是 `defn-`，外面用不到，自己跑 `ap/argparse`、`store/load`），再用 `(merge cli/commands {"count" cmd-count})` 組一張新表，寫一個小小的 `my-run` 照表分派。
2. 先猜再跑：`todo done 0` 和 `todo done 2.5` 各印什麼？是 `parse-id` 裡哪一個檢查擋下來的？

答案在 `examples/course/11-3.janet` 最後，跑 `janet examples/course/11-3.janet` 可以看到結果。

## 想更深

- [docs/04 命令列與 argparse](../docs/04-cli-argparse.md)：「子命令」那段是同一招的精簡版，還有 `:required`、`:map` 這些這課沒用到的選項。
- [snippets/cli-skeleton.janet](../snippets/cli-skeleton.janet)：一支真 CLI 的骨架，把 exit code 分成「用法錯」和「執行失敗」、加上日誌等級與讀 stdin。
- [docs/01d 提早離開](../docs/01d-提早離開-return-break-continue.md)：函式裡的 `break`、`label`、`prompt` 怎麼選。

下一課：[11-4 · todo 測試與打包](11-4-todo-測試與打包.md)
