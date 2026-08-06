# Janet 教學 · 目錄

給這台機器上的 Janet 開發環境。每篇的程式碼都在 Janet 1.41.2 上實際跑過。

00 → 06 依序讀完就能上手；07 之後每篇獨立，需要時再翻。

| # | 篇 | 重點 |
|---|----|------|
| 00 | [環境與工具鏈](00-環境與工具鏈.md) | 裝在哪、三個常用指令、原始碼編譯的理由（Manjaro） |
| 00b | [Windows + VS Code](00b-windows-vscode.md) | ★ 搬到 Windows 實測：jpm 改 mingw、自備 `libjanet.a`、Janet++、中文 argv 坑 |
| 01 | [語言速成](01-語言速成.md) | 括號家族 `() [] {} @`、def/let、函式、條件、迴圈、`print` vs `pp` |
| 02 | [資料結構](02-資料結構.md) | array / tuple / table / struct，`@` 的意義，`get-in` |
| 03 | [JSON](03-json.md) | `spork/json`：字面≈JSON、encode/decode、null 陷阱、巢狀改值 |
| 04 | [CLI 參數](04-cli-argparse.md) | `spork/argparse` 四種 kind、自動 help、**子命令**（git 風格） |
| 05 | [jpm 與專案](05-jpm-與專案.md) | 專案結構、`project.janet` 三個宣告、test / build / deps、裝套件 |
| 05b | [建立新專案](05b-建立新專案.md) | `jpm new-project`／`new-exe-project`／`new-c-project`；★ **`main` 會被自動呼叫** |
| 05c | [jpm 的 rule 系統](05c-jpm-的-rule-系統.md) | `jpm run` **不是** `cargo run`、`rules`／`phony`；★ **build 什麼時候不重編** |
| 05d | [引用自己的另一個專案](05d-引用自己的專案.md) | 跨專案相對路徑 import 的坑、從本地 repo `jpm install` 的兩個前提 |
| 06 | [編輯器與 REPL](06-編輯器與-REPL.md) | Conjure `,ee` 工作流、parinfer、（可選）janet-lsp |
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

## 最快上手路線

1. `janet` 開 REPL（[07](07-repl.md)），把 [01](01-語言速成.md) 的片段貼進去玩。
2. 看 [02](02-資料結構.md) 建立 array / table 的手感。
3. 你最常用的兩個庫直接看 [03 JSON](03-json.md) 和 [04 argparse](04-cli-argparse.md)（含子命令）。
4. 進階招牌：[14 PEG](14-peg.md)、[09 fiber](09-fiber.md) + [15 ev/net](15-ev-channel-net.md)、[08 macro](08-巨集-macro.md)、[10 C 互通](10-c-互通.md)。
5. 看根目錄 `bin/main.janet` 與 [`examples/`](../examples/README.md)——都是可跑的實例。
