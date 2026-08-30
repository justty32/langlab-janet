# Janet 教學 · 目錄

給這台機器上的 Janet 開發環境。每篇的程式碼都在 Janet 1.41.2 上實際跑過。

00 → 06 依序讀完就能上手；07 之後每篇獨立，需要時再翻。

> **從 C++ 過來的？** 有專門的讀法，見 [路線圖](路線圖.md)。

## 基礎篇（依序讀）

| # | 篇 | 重點 |
|---|----|------|
| 00 | [環境與工具鏈](00-環境與工具鏈.md) | 裝在哪、三個常用指令、原始碼編譯的理由（Manjaro） |
| 00b | [Windows + VS Code](00b-windows-vscode.md) | ★ 搬到 Windows 實測：jpm 改 mingw、自備 `libjanet.a`、Janet++、中文 argv 坑 |
| 01 | [語言速成](01-語言速成.md) | 括號家族 `() [] {} @`、def/let、函式、條件、迴圈、`print` vs `pp` |
| 01b | [給 C++ 開發者的對照](01b-給-C++-開發者.md) | ★ 概念對照表、`=` 的兩套語意、沒有值拷貝、沒有重載、GC 與 RAII |
| 01c | [解構與執行緒巨集](01c-解構與執行緒巨集.md) | 把樣板碼壓短的兩招：`def [a b & rest]`、`->`／`->>`／`-?>`／`as->` |
| 02 | [資料結構](02-資料結構.md) | array / tuple / table / struct，`@` 的意義，`get-in` |
| 03 | [JSON](03-json.md) | `spork/json`：字面≈JSON、encode/decode、null 陷阱、巢狀改值 |
| 04 | [CLI 參數](04-cli-argparse.md) | `spork/argparse` 四種 kind、自動 help、**子命令**（git 風格） |
| 05 | [jpm 與專案](05-jpm-與專案.md) | 專案結構、`project.janet` 三個宣告、test / build / deps、裝套件 |
| 05b | [建立新專案](05b-建立新專案.md) | `jpm new-project`／`new-exe-project`／`new-c-project`；★ **`main` 會被自動呼叫** |
| 05c | [jpm 的 rule 系統](05c-jpm-的-rule-系統.md) | `jpm run` **不是** `cargo run`、`rules`／`phony`；★ **build 什麼時候不重編** |
| 05d | [引用自己的另一個專案](05d-引用自己的專案.md) | 跨專案相對路徑 import 的坑、從本地 repo `jpm install` 的兩個前提 |
| 05e | [import 與模組路徑](05e-import-與模組路徑.md) | 相對路徑相對「寫這行的檔案」、⚠ `~` 是 quasiquote 不是家目錄、`:as`／`:prefix`、import 要放頂層 |
| 06 | [編輯器與 REPL](06-編輯器與-REPL.md) | Conjure `,ee` 工作流、parinfer、（可選）janet-lsp |

## 日常會用到的（建議接著看）

| # | 篇 | 重點 |
|---|----|------|
| 18 | [字串與 buffer](18-字串與-buffer.md) | string／buffer 之分、`string/*` 參數順序坑、格式動詞、byte 不是字元 |
| 19 | [檔案與檔案系統](19-檔案與檔案系統.md) | `slurp`／`spit`、`with` + file handle、開檔模式、★ Windows 換行陷阱 |
| 19b | [檔案系統與路徑](19b-檔案系統與路徑.md) | `os/stat`、走目錄、`spork/path` 組路徑（別自己接字串） |
| 20 | [錯誤處理與資源管理](20-錯誤處理與資源管理.md) | `error`／`try`／`protect`／`assert`、`defer`／`with`＝RAII、何時回 nil 何時拋錯 |
| 21 | [數字與位元](21-數字與位元.md) | ★ 全部是 double、`/` vs `div` vs `mod` vs `%`、位元運算是 32-bit、`int/u64` |
| 22 | [原型與方法](22-原型與方法.md) | Janet 版的「類別」：`(:method obj)`、原型鏈＝vtable、三個陷阱、配合 `with` |
| 23 | [測試怎麼寫](23-測試怎麼寫.md) | 沒有測試框架、`assert`／`protect`／`deep=`、★ 一支失敗不擋其他支 |
| 23b | [用 spork/test 寫測試](23b-用-spork-test-寫測試.md) | 失敗不中止整支檔、`assert-error`、⚠ `skip-asserts` 會讓 suite 變紅 |
| 24 | [時間與日期](24-時間與日期.md) | `os/time`／`strftime`／`mktime`、計時用 monotonic、★ **月與日是 0-based** |
| 25 | [序列工具](25-序列工具.md) | `map`／`filter`／`reduce` 家族的四條規則、★ 輸出幾乎都是 array |
| 26 | [隨機數](26-隨機數.md) | PRNG／`math/rng`／`os/cryptorand` 三選一、★ **預設每次跑都一樣** |
| 26b | [隨機數配方](26b-隨機數配方.md) | 擲骰、抽一個、洗牌（Fisher-Yates）、隨機 ID |
| 32 | [條件與模式比對](32-條件與模式比對.md) | ★ **`match` 比形狀還綁內容**（C++ 沒有的東西）、⚠ tuple 模式是前綴比對、`case` 對 array 永遠不中、`when-let` 家族 |
| 32b | [loop 全表](32b-loop-全表.md) | 八個 verb ＋ 八個條件詞、⚠ **`:range` 負步長靜默給空的**、`:before`/`:after` 是每圈都跑 |
| 33 | [函式參數與閉包](33-函式參數與閉包.md) | `&opt`／`& rest`／`&named`／`&keys`、★ **arity 是編譯期檢查、`try` 攔不到**、閉包捕獲的是綁定（對照 C++ 的 `[&]`）、⚠ 迴圈裡建閉包 |
| 34 | [讀錯誤訊息與除錯](34-讀錯誤訊息.md) | parse／compile／runtime 三類的分辨、★ **尾呼叫會吃掉堆疊那一層**、常見訊息翻譯、⚠ 「呼叫 nil」為什麼在講參數型別、`trace` |

## 需要時再翻的兩區

**主題篇（07–17）**——REPL／巨集／fiber／C 互通／子行程／env／PEG／ev／marshal／HTTP，
以及 **spork 篇（27–31）**——準標準庫的地圖與五篇專題，
兩區都是「用到才翻」，所以另成一份索引：[主題與 spork 索引](主題與-spork-索引.md)。

> 想快速查：**[`html/index.html`](../html/index.html)** 是分頁速查表（核心／資料IO／PEG／並行／C互通／env），開瀏覽器即看。
> 可跑範例在 [`examples/`](../examples/README.md)（教學附件）與 [`snippets/`](../snippets/README.md)（做事的起點）。

## 怎麼讀這份教學

**閱讀順序**（最快上手路線、從 C++ 過來的路線、每篇都有的 ⚠／★ 標記是什麼意思）
另成一篇：[路線圖](路線圖.md)。

想查**某個領域完整有哪些函式可用**（而不是學概念）→ [`reference/`](../reference/README.md)。
