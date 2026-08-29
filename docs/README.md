# Janet 教學 · 目錄

給這台機器上的 Janet 開發環境。每篇的程式碼都在 Janet 1.41.2 上實際跑過。

00 → 06 依序讀完就能上手；07 之後每篇獨立，需要時再翻。

> **從 C++ 過來的話**：先看 [01 語言速成](01-語言速成.md)，再看
> [**01b 給 C++ 開發者的對照**](01b-給-C++-開發者.md)——一張概念對照表加五個一定會誤會的地方，
> 讀完之後 02 以後的內容會快非常多。接著 [21 數字與位元](21-數字與位元.md) 也建議早點看，
> 因為 Janet 的數字模型跟 C++ 差最多。

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
| 24 | [時間與日期](24-時間與日期.md) | `os/time`／`strftime`／`mktime`、計時用 monotonic、★ **月與日是 0-based** |
| 25 | [序列工具](25-序列工具.md) | `map`／`filter`／`reduce` 家族的四條規則、★ 輸出幾乎都是 array |
| 26 | [隨機數](26-隨機數.md) | PRNG／`math/rng`／`os/cryptorand` 三選一、★ **預設每次跑都一樣** |
| 26b | [隨機數配方](26b-隨機數配方.md) | 擲骰、抽一個、洗牌（Fisher-Yates）、隨機 ID |

## 主題篇（需要時再翻）

| # | 篇 | 重點 |
|---|----|------|
| 07 | [REPL 用法](07-repl.md) | 開關、`doc`、載入模組、`dyn`、跟 Conjure 的關係 |
| 08 | [巨集 macro](08-巨集-macro.md) | `~ , ,;`、`defmacro`、`macex1` 除錯、`with-syms` 衛生 |
| 09 | [Fiber 協程](09-fiber.md) | generator、例外即 fiber、信號遮罩、`ev` 非同步 |
| 10 | [與 C 互通](10-c-互通.md) | 三種接法的差別、FFI 最小範例、`ffi/defbind` |
| 10b | [FFI：型別、指標與記憶體](10b-ffi-型別與指標.md) | 型別關鍵字全表、`ffi/write`／`read`、out 參數、struct、`malloc` |
| 10c | [FFI：字串回傳與地雷合輯](10c-ffi-字串與地雷.md) | `char*` 怎麼變 Janet 字串、指標地雷、回呼 |
| 10d | [native 模組與嵌入](10d-native-與嵌入.md) | 用 C 寫 Janet 函式、把 Janet 塞進 C 程式 |
| 11 | [子行程 / 管線 / 信號](11-pipeline-signal.md) | `os/execute`、`sh/exec-slurp`、管線兩法、`proc-kill`、`sigaction` |
| 12 | [env：環境表](12-env-環境與動態變數.md) | `curenv`、一個綁定裡有什麼、列出所有綁定、查 symbol 型別 |
| 12b | [切換 env](12b-切換-env.md) | `make-env`、`fiber/setenv`、`dofile`／`run-context`、`import` 的 env 選項 |
| 12c | [動態變數 dyn](12c-dyn.md) | **`dyn` 到底是什麼**（動態作用域 vs 全域變數）、`with-dyns`、per-fiber |
| 12d | [OS 環境變數](12d-os-環境變數.md) | `os/getenv`、給子行程指定環境（`:pe` 的坑）、`JANET_PATH`、速查 |
| 13 | [symbol / keyword / 字串](13-symbol-keyword-字串.md) | 四種「名字」型別、`"abc"` ↔ `:abc` 互轉、跨型別 `=` 的坑 |
| 14 | [PEG 解析器](14-peg.md) | 內建 PEG：組合子、捕獲、具名文法、遞迴、解 log／CSV |
| 15 | [ev：channel / 執行緒](15-ev-channel-net.md) | channel、真 OS 執行緒、select/gather、逾時取消 |
| 15b | [net 與速查](15b-net-與速查.md) | 五行 TCP server、常用 API 一覽、地雷清單 |
| 16 | [marshal 與自省](16-marshal-與自省.md) | 序列化閉包與 fiber、image、`disasm`／`trace`／`comptime`、spork 全櫃 |
| 17 | [用 spork/http 打 API](17-用-spork-http-打-api.md) | POST 寫法、buffer／status 兩個雷、沒 TLS 沒串流、★ **HTTP 200 不代表拿到完整答案** |

> 想快速查：**[`html/index.html`](../html/index.html)** 是分頁速查表（核心／資料IO／PEG／並行／C互通／env），開瀏覽器即看。
> 可跑範例在 [`examples/`](../examples/README.md)（教學附件）與 [`snippets/`](../snippets/README.md)（做事的起點）。

## 怎麼讀這份教學

**閱讀順序**（最快上手路線、從 C++ 過來的路線、每篇都有的 ⚠／★ 標記是什麼意思）
另成一篇：[路線圖](路線圖.md)。

想查**某個領域完整有哪些函式可用**（而不是學概念）→ [`reference/`](../reference/README.md)。
