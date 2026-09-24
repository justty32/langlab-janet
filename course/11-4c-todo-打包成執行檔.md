# 11-4c · todo：打包成執行檔

接 [11-4b](11-4b-todo-指令層測試.md)。測試綠了，最後一步是把 todo 編成一支原生執行檔（native executable，作業系統直接就能跑的程式，像 `ls` 那樣），拿到沒裝 Janet 的機器上也能用。

## 動手：jpm build

`project.janet` 最後一段就是在講這件事：

```janet
(declare-executable
  :name "todo"
  :entry "main.janet"
  :install false)
```

`:name` 是產出的檔名，`:entry` 是進入點，`:install false` 表示 `jpm install` 時不要把它裝進系統。在 `examples/course/11-todo/` 裡跑（先 `jpm clean` 確保是乾淨的）：

```sh
$ jpm build
generating executable c source build/todo.c from main.janet...
found native /home/lorkhan/.local/lib/janet/spork/json.so...
compiling build/todo.c to build/build___todo.o...
linking build/todo...
$ ls build/
build___todo.o  todo  todo.c
$ file build/todo
build/todo: ELF 64-bit LSB pie executable, x86-64, ...
```

jpm 把 `main.janet` 和它 import 的所有東西（連 spork 的 json）先跑一遍，把跑完的結果塞進一個 C 檔，再用 C 編譯器編成 `build/todo`。這支檔自己就帶著 Janet 的執行環境，不需要另外裝 janet。

直接跑跑看，環境變數和 `--file` 都照樣有效：

```sh
$ TODO_FILE=/tmp/b.json ./build/todo add 用執行檔加的
新增 #1：用執行檔加的
$ ./build/todo list --file /tmp/b.json
[ ] 1  用執行檔加的
```

玩完把產物刪掉。`build/` 是編出來的東西，不進 repo：

```sh
$ jpm clean
Deleted build directory build
```

## 你會踩的坑

⚠ 改了檔案，`jpm build` 卻沒重編。

你會以為：改了 `todo/cli.janet`，再 `jpm build` 就會拿到新版。

其實是：`jpm build` 什麼都不印就結束了，`./build/todo` 還是舊的行為。實測把 `（沒有事情）` 改成 `（空的）` 之後 build，跑出來還是 `（沒有事情）`。

因為：jpm 只看 `:entry` 那支檔（`main.janet`）有沒有比產物新，不會去追它 import 的其他檔。改了非入口檔就 `jpm clean && jpm build`，保證從頭編。

⚠ 頂層讀的環境變數被凍在 build 那一刻。

你會以為：把資料檔路徑寫成頂層的 `(def path (or (os/getenv "TODO_FILE") "todo.json"))`，每次執行都會去讀當下的 `TODO_FILE`。

其實是：`janet main.janet` 跑的時候沒事，編成執行檔之後，它永遠用 build 當下的值。用一個小專案實測：

```janet
(def top-path (or (os/getenv "TODO_FILE") "todo.json"))      # 頂層：載入時就算好
(defn fn-path [] (or (os/getenv "TODO_FILE") "todo.json"))   # 函式：每次呼叫才算
(defn main [& _]
  (print "頂層算的：" top-path)
  (print "函式算的：" (fn-path)))
```

```sh
$ TODO_FILE=/a.json janet main.janet
頂層算的：/a.json
函式算的：/a.json
$ jpm build && TODO_FILE=/a.json ./build/freeze
頂層算的：todo.json        # 凍在 build 那一刻（build 時沒設 TODO_FILE）
函式算的：/a.json
```

因為：jpm build 的做法就是「先把整支程式載入跑一遍，把跑完的狀態存進執行檔」。頂層的 `def` 在載入時就算好了，算出來的字串跟著被存進去，之後執行只是把存好的值拿出來，不會再問一次作業系統。函式本體則是等到 `main` 真的呼叫它才跑，那時候讀到的才是當下的環境變數。

這就是 `store/data-path` 把 `os/getenv` 放在函式裡的原因：

```janet
(defn data-path
  [&opt override]
  (or override (os/getenv "TODO_FILE") "todo.json"))
```

規則很簡單：任何「每次執行都可能不一樣」的東西（環境變數、目前時間、目前目錄、命令列參數），都放進函式裡，由 `main` 開始的呼叫鏈去讀，不要寫在頂層。

## 小練習

1. 幫 `list --all` 補一條測試：add 兩筆、done 第一筆，檢查 `list`、`list --all`、`list -a` 各印出什麼。寫在自己的檔裡，用 capture-stdout 包 `cli/run`，不要改專案的 `test/`。
2. 寫一條斷言：add 兩筆、`rm` 第二筆之後，`next-id` 還是 3，再 add 一筆拿到的 id 是 3 不是 2（id 不會倒退，也不會撞號）。
3. store 測試只檢查了「JSON 語法錯」的訊息帶路徑。補一條：寫入 `[1, 2]`（形狀不對）時，錯誤訊息也要帶路徑。

答案在 `examples/course/11-4.janet` 最後，跑 `janet examples/course/11-4.janet` 會看到三題都通過。

整個 todo 到這裡就完成了：規劃、資料層、指令層、測試、打包，一個真的能用的命令列工具該有的都有了。

## 想更深

- [docs/23 測試怎麼寫](../docs/23-測試怎麼寫.md)：assert 風格測試的更多配方，還有 jpm test 怎麼挑檔。
- [docs/23b 用 spork/test 寫測試](../docs/23b-用-spork-test-寫測試.md)：spork/test 的全部工具，不只這課用到的兩個。
- [docs/05c jpm 的 rule 系統](../docs/05c-jpm-的-rule-系統.md)：jpm 怎麼判斷要不要重編，為什麼改非入口檔不會觸發。
- [FINDINGS 踩坑 b 工具鏈](../FINDINGS-踩坑b-工具鏈.md) 第二十五節：執行檔凍住設定檔探測的原始紀錄。

下一課：[11-5 · 接下來去哪](11-5-接下來去哪.md)
