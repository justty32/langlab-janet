# 需要時再翻 · 主題篇與 spork 篇

[← docs 目錄](README.md)

[README](README.md) 收的是**依序讀**的兩區（基礎篇 00–06、日常會用到的 18–26）；
這份收**需要時再翻**的兩區：主題篇（07–17）與 spork 篇（27–31）。

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

## spork 篇（準標準庫）

`spork` 不是內建，但幾乎人人都裝——51 個模組。從 27 的地圖開始挑。

| # | 篇 | 重點 |
|---|----|------|
| 27 | [spork 全覽](27-spork-全覽.md) | 地圖：七大類、⚠ **不要 `(import spork)`**、原生模組與 Windows 的坑 |
| 28 | [spork/misc 順手工具](28-spork-misc-順手工具.md) | ★ `map-vals` 補了「字典不好處理」的洞、`randomize-array` 洗牌 |
| 28b | [spork/misc 文字與流程](28b-spork-misc-文字與流程.md) | `dedent`、印表格（⚠ 中文對不齊）、`capout`、dyn 當開關的 logger |
| 29 | [spork 資料與文字](29-spork-資料與文字.md) | `schema` 驗證的 quote 坑、`base64`／`crc`／`zip`、★ **regex 其實是 PEG**、`date` 格式碼 |
| 30 | [spork 並行與服務](30-spork-並行與服務.md) | ★ `pmap` 並行但**保序**、`generators` 真惰性、⚠ `channel/from-each` 沒喝完會卡死 |
| 31 | [spork 產生 HTML](31-spork-產生-html.md) | `htmlgen` 用資料結構、`temple` 用模板、★ **兩者都自動跳脫** |
| 41 | [spork 終端與 shell](41-spork-終端與-shell.md) | `sh-dsl` 的 `\|` 真的是管線、⚠ `$<` 回 buffer、★ **`rawterm/monowidth` 讓中文表格對得齊**、⚠ `rawterm/size` 非 tty 回垃圾 |
| 42 | [spork/math](42-spork-math.md) | 統計／檢定／線性代數／數論、⚠ **沒有 `mean`**、⚠ **函式名拼錯（`binominal-coeficient`）**、⚠ `permutations` 只吃 `@[]`、`primes` 是無界 fiber |

> 想快速查：**[`html/index.html`](../html/index.html)** 是分頁速查表，開瀏覽器即看。
> 完整函式清單看 [`reference/`](../reference/README.md)。
