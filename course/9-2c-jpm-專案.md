# 9-2c · jpm 會咬人的地方

接續 [9-2b · jpm 日常指令](9-2b-jpm-專案.md)。

## 你會踩的坑

### ⚠ 改了 demo/init.janet，jpm build 卻不重編

你會以為：改了程式再 `jpm build`，執行檔就會是新的。

其實是：只改 `bin/main.janet` 以外的檔，`jpm build` 什麼都不做，也不報錯。在 9-demo 裡實測，先 build 一次，戳一下 `demo/init.janet` 再 build：

```sh
jpm build
ls -la --time-style=+%H:%M:%S build/demo
touch demo/init.janet
jpm build
ls -la --time-style=+%H:%M:%S build/demo
```

```text
generating executable c source build/demo.c from bin/main.janet...
compiling build/demo.c to build/build___demo.o...
linking build/demo...
-rwxr-xr-x 1 lorkhan lorkhan 2140256 14:57:49 build/demo
-rwxr-xr-x 1 lorkhan lorkhan 2140256 14:57:49 build/demo
```

第二次 `jpm build` 一個字都沒印，執行檔時間停在 14:57:49。在專案副本裡把 `greet` 的 `"Hello, "` 真的改成 `"Hi, "`，`janet bin/main.janet Ann` 印 `Hi, Ann!`，`jpm build` 之後的 `./build/demo Ann` 卻還是 `Hello, Ann!`。

因為：jpm 是 make 式的，靠比時間決定要不要重做。`declare-executable` 生出的 rule 只把 `:entry` 那一支當成材料，不會去追它 import 了誰。`bin/main.janet` 沒變，rule 就認定產物是最新的。解法是 `jpm clean && jpm build`，重編後時間變成 14:57:52，內容也對了。看到「明明改了卻沒反應」，先查執行檔的時間。

### ⚠ jpm run 不是 cargo run

你會以為：`jpm run` 像 `cargo run`、`npm start`，會編完直接執行。

其實是：`jpm run X` 只跑名叫 X 的 rule，不會幫你執行 `build/demo`。

因為：jpm 的指令就是 rule 的名字。要一鍵編完就跑，自己在 `project.janet` 加一條 `phony`（見小練習）。

### ⚠ jpm new 不存在

你會以為：跟 `cargo new` 一樣打 `jpm new 名字`。

其實是：它印出 `invalid command new` 和一大段用法說明，而且結束碼還是 0，腳本裡不會發現失敗。

因為：jpm 的指令叫 `new-project`、`new-c-project`、`new-exe-project`，沒有短的 `new`。

### ⚠ :source 給目錄，安裝後多一層

你會以為：`:source ["demo"]` 等於「把 demo 目錄裡的檔都列進去」。

其實是：整個目錄連名字一起被複製。在副本裡用 `jpm install --modpath=暫存目錄` 實測，逐檔列出時裝成 `demo/init.janet`，給目錄時變成 `demo/demo/init.janet`，別人得寫 `(import demo/demo/init)`。

因為：`:source` 裡的每一項原樣複製到 `modpath/前綴/` 底下，檔案就複製檔案，目錄就連目錄名一起搬。所以要逐檔列。

## 小練習

1. 改 `examples/course/9-2.janet` 的 `main`，多印一行「使用者給了幾個參數」（不算程式自己）。用 `janet examples/course/9-2.janet a b c` 驗證印出 3。
2. 在一份 9-demo 的副本裡，替 `project.janet` 加一條叫 `go` 的 phony rule，讓 `jpm run go` 先 build 再執行 `./build/demo Ann`。提示：`(phony "名字" ["依賴的 rule"] 要做的事)`，執行外部程式用 `os/execute`。
3. 你改了 `demo/init.janet`，`./build/demo` 跑出來還是舊的。該打哪一行指令？

答案在 `examples/course/9-2.janet` 最後。做完記得 `jpm clean`，別把 `build/` 留在專案裡。

## 想更深

- [docs/05 jpm 與專案](../docs/05-jpm-與專案.md)：從 git URL 裝套件、加一個依賴的三步驟，以及另外三篇的地圖。
- [docs/05b 建立新專案](../docs/05b-建立新專案.md)：`new-project`、`new-exe-project`、`new-c-project` 三種骨架差在哪。
- [docs/05c jpm 的 rule 系統](../docs/05c-jpm-的-rule-系統.md)：`rule` 與 `phony` 怎麼寫、`jpm rule-tree`。

下一課：[9-3 · 寫測試](9-3-寫測試.md)
