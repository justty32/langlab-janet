# Janet 從零課程（下半部）

接 [上半部目錄](README.md)（單元 1–6 與「怎麼用」）。

## 單元 7 · 錯誤與資源

| 課 | 篇 | 學完你會知道 |
|----|----|------|
| 7-1 | [錯誤怎麼丟、怎麼接](7-1-錯誤怎麼丟怎麼接.md) | error 丟、try 接、protect 回 (成功? 值)、errorf／assert；錯誤是任何值，丟 table 就能帶欄位 |
| 7-1b | [往上丟、回 nil、常見的坑](7-1b-往上丟與回-nil.md) | propagate 保留現場往上丟、往上丟前補說明；查不到回 nil、本該成功才拋錯；try 接不到 compile error |
| 7-2 | [資源收尾：defer 與 with](7-2-資源收尾-defer-with.md) | 收尾綁在區塊不綁在物件上；defer 收尾寫前面（跟 Go 相反）、body 炸了照樣收；with 離開就 :close |
| 7-2b | [defer 與 with 的坑](7-2b-defer-與-with-的坑.md) | 順序寫反不報錯只顛倒、沒 :close 會炸、收尾自己炸會蓋掉 body 的錯、handle 不會自動關 |
| 7-3 | [讀錯誤訊息](7-3-讀錯誤訊息.md) | parse／compile／runtime 三類看第一行分、只有 runtime 有 trace；拿真實 crash 逐行讀；常見訊息對照表 |
| 7-3b | [尾呼叫與 trace 的坑](7-3b-尾呼叫與-trace-的坑.md) | 尾呼叫吃掉一層、(tail call) 標記是線索；debug/stacktrace 第三個參數不能省；「呼叫 nil」的訊息在講參數型別 |

## 單元 8 · 檔案與命令列

| 課 | 篇 | 學完你會知道 |
|----|----|------|
| 8-1 | [讀寫檔案](8-1-讀寫檔案.md) | 整檔讀寫用 slurp／spit，大檔一行一行讀用 file/open 配 with；讀回來的是 buffer 不是字串 |
| 8-1b | [讀寫檔案（一行一行讀）](8-1b-讀寫檔案.md) | file/open ＋ with 自動關檔、模式字串、file/read :line／:all、打不開回 nil 與 Windows 換行兩個坑 |
| 8-2 | [目錄與路徑](8-2-目錄與路徑.md) | os/stat 查在不在、os/dir 列目錄、os/mkdir／os/rm 建刪；路徑一律交給 spork/path 組 |
| 8-2b | [目錄與路徑（續）](8-2b-目錄與路徑.md) | spork/path 組拆路徑，加上把 .txt 行數加總的小工具 |
| 8-3 | [命令列參數](8-3-命令列參數.md) | (dyn *args*) 拿原始參數，spork/argparse 四種 kind 解析成 table，--help 免費送；值全是字串 |

## 單元 9 · 模組與專案

| 課 | 篇 | 學完你會知道 |
|----|----|------|
| 9-1 | [import 與拆檔](9-1-import-與拆檔.md) | import 是跑那支檔拿它的名字；./ 相對的是寫這行的檔，不是你 cd 在哪 |
| 9-1b | [import 的規則與坑](9-1b-import-的規則與坑.md) | import 放頂層、只載入一次、私有拿不到；~ 不是家目錄、/ 會被吃掉 |
| 9-2 | [jpm 專案](9-2-jpm-專案.md) | 什麼時候才需要專案、project.janet 三個宣告、main 會被自動呼叫 |
| 9-2b | [jpm 日常指令](9-2b-jpm-專案.md) | 開發期直接 janet 跑；jpm test 會先 build；build／clean／deps／rules／install |
| 9-2c | [jpm 會咬人的地方](9-2c-jpm-專案.md) | 改了非入口檔 build 不重編、jpm run 不是 cargo run、沒有 jpm new、:source 給目錄多一層 |
| 9-3 | [寫測試](9-3-寫測試.md) | 一支測試就是普通程式，跑完算過、丟錯算失敗；jpm test 把 test/ 每支檔各開一個行程跑 |
| 9-3b | [測試配方與 spork/test](9-3b-測試配方與-spork-test.md) | 集合用 deep=、該失敗用 protect、浮點比差值；spork/test 一條失敗照樣跑完 |
| 9-3c | [選哪套與會踩的坑](9-3c-選哪套與會踩的坑.md) | 內建 assert 與 spork/test 怎麼挑；省訊息、= 比 array、假測試、skip-asserts 這些坑 |

## 單元 10 · 招牌功能

| 課 | 篇 | 學完你會知道 |
|----|----|------|
| 10-1 | [fiber：可以暫停再繼續的函式](10-1-fiber.md) | fiber/new、resume、yield；當 generator 走訪；try 底層就是 fiber 攔 error |
| 10-2 | [ev 非同步：一條執行緒輪流跑很多件事](10-2-ev-非同步.md) | ev/spawn、ev/sleep、ev/chan、gather、with-deadline、cancel；忙迴圈會卡死整個程式 |
| 10-3 | [PEG：用規則拆字串](10-3-PEG.md) | 從比對一個數字加到解析多行 key=value；`<-` 抓、`/` 轉、具名文法；正則的替代品 |
| 10-4 | [巨集：在程式跑之前先改寫程式碼](10-4-巨集.md) | 程式碼即 tuple、`~` `,` `,;`、defmacro、macex1 看展開、with-syms；能用函式就別寫巨集 |
| 10-5 | [原型與方法：Janet 的物件就這麼多](10-5-原型與方法.md) | `(:speak dog)` 展開成什麼、table/setproto 原型鏈、:close 配 with；`(:port cfg)` 不是取值 |

## 單元 11 · 綜合小專案：todo 命令列工具

| 課 | 篇 | 學完你會知道 |
|----|----|------|
| 11-1 | [todo：規劃與骨架](11-1-todo-規劃與骨架.md) | 要做的工具長什麼樣、為什麼拆資料層與指令層、資料形狀與 next-id |
| 11-1b | [todo 的骨架](11-1b-todo-骨架.md) | 目錄、project.janet 三宣告、七行 main.janet、main → cli → store 的 import 路徑 |
| 11-2 | [todo 資料層](11-2-todo-資料層.md) | 資料檔放哪、JSON 怎麼存怎麼讀；檔案不存在回空的，壞掉就拋出帶路徑的錯誤 |
| 11-2b | [todo 資料層（改資料與存讀一圈）](11-2b-todo-資料層.md) | add／done／rm 找不到就回 nil，存進去再讀出來要一模一樣 |
| 11-3 | [todo 指令層](11-3-todo-指令層.md) | argparse 沒有子命令，就看第一個字分派、墊個程式名再各跑一次 argparse；parse、with-db 把重複的步驟抽掉 |
| 11-3b | [todo 指令層（續）](11-3b-todo-指令層.md) | list、done、rm 與總入口 run：查表分派、protect 把錯誤接成一行、錯誤走 stderr |
| 11-3c | [todo 指令層跑起來](11-3c-todo-指令層.md) | 從終端機實際跑一輪，加上 --help 回 1、argparse 印在 stdout、protect 吞 bug 等坑 |
| 11-4 | [todo：測試與打包](11-4-todo-測試與打包.md) | 測試放 test/、用暫存目錄加 defer 不碰真資料，逐條看資料層測了什麼 |
| 11-4b | [todo：指令層測試與 jpm test](11-4b-todo-指令層測試.md) | 直接呼叫 cli/run，用 capture-stdout／suppress-stderr 驗 exit code 與輸出，第一次 jpm test 會先 build |
| 11-4c | [todo：打包成執行檔](11-4c-todo-打包成執行檔.md) | jpm build 編出不用裝 janet 的執行檔，jpm clean 清掉；頂層 os/getenv 會被凍在 build 那一刻 |
| 11-5 | [接下來去哪](11-5-接下來去哪.md) | 回顧十一個單元，對照 todo 用到了哪些，數一數 repo 五個區 |
| 11-5b | [五個區怎麼用](11-5b-五個區怎麼用.md) | docs／reference／cheatsheets／snippets／exercises 各什麼時候去、47 系列 AI agent、三個下一步 |

學完了？回 [上半部目錄](README.md)，或照 [11-5b](11-5b-五個區怎麼用.md) 挑一個下一步。
