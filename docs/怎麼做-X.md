# 我要做 X，去哪

[← docs 目錄](README.md)

其他索引都是**按主題**排的（語言核心、spork、語言細節）。這份按**任務**排——
你腦中想的是「我現在要做這件事」，不是「這屬於哪一章」。

三欄的意思：**教學**＝為什麼與觀念、**可跑**＝直接跑起來看、**抄**＝貼進你的專案改。

## 輸入與輸出

| 我要… | 教學 | 可跑 | 抄 |
|-------|------|------|-----|
| 讀寫檔案 | [19](19-檔案與檔案系統.md) | — | [`file-io`](../snippets/file-io.janet) |
| 查一個路徑（存在？資料夾？改過沒？）| [19b](19b-檔案系統與路徑.md) | — | [`file-info`](../snippets/file-info.janet)、[`list-dir`](../snippets/list-dir.janet) |
| 組路徑（別自己接字串）| [19b](19b-檔案系統與路徑.md) | — | — |
| 讀寫 JSON | [03](03-json.md) | — | [`json-and-marshal`](../snippets/json-and-marshal.janet) |
| 讀寫 **CSV**（引號、欄內逗號與換行）| [14 PEG](14-peg.md) | [`peg-demo`](../examples/peg-demo.janet) | [`csv`](../snippets/csv.janet) |
| 存 Janet 資料到檔案再讀回來 | [16](16-marshal-與自省.md) | — | [`json-and-marshal`](../snippets/json-and-marshal.janet) |
| 處理二進位（讀檔頭、大端序）| [21](21-數字與位元.md) | — | [`binary-png`](../snippets/binary-png/main.janet) |
| 非同步讀 stdin | [15](15-ev-channel-net.md) | — | [`stdin-async`](../snippets/stdin-async.janet) |

## 做一支命令列工具

| 我要… | 教學 | 可跑 | 抄 |
|-------|------|------|-----|
| 解析參數 | [04](04-cli-argparse.md) | [`subcommands`](../examples/subcommands.janet) | [`argv-parse`](../snippets/argv-parse.janet) |
| **把整支工具的骨架搭起來** | [04](04-cli-argparse.md)、[20](20-錯誤處理與資源管理.md) | — | ★ [`cli-skeleton`](../snippets/cli-skeleton.janet) |
| 子命令（git 風格）| [04](04-cli-argparse.md) | [`subcommands`](../examples/subcommands.janet) | — |
| 載入設定（檔案＋環境變數＋驗證）| [29](29-spork-資料與文字.md) | — | ★ [`config-load`](../snippets/config-load.janet) |
| 終端上色、進度條（接管線自動關掉）| [39](39-跟作業系統打交道.md) | [`os-tour`](../examples/os-tour.janet) | [`term-color`](../snippets/term-color.janet) |
| **印中文也對得齊的表格** | [41](41-spork-終端與-shell.md) | [`term-shell`](../examples/term-shell.janet) | ★ [`aligned-table`](../snippets/aligned-table.janet) |
| 跑完掉進 REPL 讓人手動探索 | [07](07-repl.md) | — | [`repl-mode`](../snippets/repl-mode.janet) |
| 編成單一執行檔 | [05c](05c-jpm-的-rule-系統.md) | — | — |

## 跟外面打交道

| 我要… | 教學 | 可跑 | 抄 |
|-------|------|------|-----|
| 跑外部命令、接管線 | [11](11-pipeline-signal.md)、[41](41-spork-終端與-shell.md) | [`pipeline`](../examples/pipeline.janet)、[`term-shell`](../examples/term-shell.janet) | [`pipe-to-child`](../snippets/pipe-to-child/) |
| 打 HTTP API | [17](17-用-spork-http-打-api.md) | — | [`http-local`](../snippets/http-local/main.janet) |
| 打 LLM | — | [`examples/llm-http/`](../examples/llm-http/README.md) | [`modules/llm-http/`](../modules/llm-http/README.md) |
| **重試與逾時** | [15](15-ev-channel-net.md) | — | ★ [`retry-timeout`](../snippets/retry-timeout.janet) |
| **並行跑一批工作（限流、單一失敗不拖垮）** | [30](30-spork-並行與服務.md) | — | ★ [`parallel-batch`](../snippets/parallel-batch.janet) |
| 判斷作業系統、處理跨平台 | [39](39-跟作業系統打交道.md) | [`os-tour`](../examples/os-tour.janet) | — |
| 呼叫 C 函式庫 | [10](10-c-互通.md)、[10b](10b-ffi-型別與指標.md) | [`ffi-demo`](../examples/ffi-demo.janet)、[`ffi-pointers`](../examples/ffi-pointers.janet) | — |

## 處理資料

| 我要… | 教學 | 可跑 | 抄 |
|-------|------|------|-----|
| map／filter／reduce | [25](25-序列工具.md) | [`seq-tools`](../examples/seq-tools.janet) | — |
| 走訪／改寫**巢狀**資料 | [35b](35b-走訪與改寫巢狀資料.md) | [`copy-freeze`](../examples/copy-freeze.janet) | — |
| 拷貝一份（淺／深）| [35](35-拷貝與凍結.md) | [`copy-freeze`](../examples/copy-freeze.janet) | — |
| 排序（多鍵、自訂比較）| [36](36-排序與比較.md) | [`sorting`](../examples/sorting.janet) | — |
| 依形狀比對並拆解 | [32](32-條件與模式比對.md) | [`match-demo`](../examples/match-demo.janet) | — |
| 解析有結構的文字 | [14](14-peg.md) | [`peg-demo`](../examples/peg-demo.janet) | [`csv`](../snippets/csv.janet) |
| 驗證資料形狀 | [29](29-spork-資料與文字.md) | — | [`config-load`](../snippets/config-load.janet) |
| 處理 UTF-8（字元數、切片）| [18](18-字串與-buffer.md) | — | [`utf8-strings`](../snippets/utf8-strings.janet) |
| 統計／線性代數／數論 | [42](42-spork-math.md) | [`spork-math`](../examples/spork-math.janet) | — |
| 亂數、洗牌、隨機 ID | [26](26-隨機數.md)、[26b](26b-隨機數配方.md) | [`random-demo`](../examples/random-demo.janet) | — |
| 時間、日期、計時 | [24](24-時間與日期.md) | [`time-demo`](../examples/time-demo.janet) | [`every-5s-clock`](../snippets/every-5s-clock.janet) |

## 出問題的時候

| 我要… | 去哪 |
|-------|------|
| **確認「這是不是已知的坑」** | ★ [`html/gotchas.html`](../html/gotchas.html)——全部實測過，每條標了出處 |
| 看懂錯誤訊息與堆疊 | [34](34-讀錯誤訊息.md)＋[`error-anatomy`](../examples/error-anatomy.janet) |
| 知道某個操作貴不貴 | [37](37-什麼操作貴.md)＋[`bench`](../examples/bench.janet)（在你機器上重跑）|
| 追某個值到底是什麼型別 | [38](38-型別全表.md)＋[`types`](../examples/types.janet) |
| 追 import 找不到模組 | [05e](05e-import-與模組路徑.md)、[40](40-內建動態變數.md)（印 `module/paths`）|
| 寫測試 | [23](23-測試怎麼寫.md)、[23b](23b-用-spork-test-寫測試.md)＋[`testing-demo`](../examples/testing-demo.janet) |

## 寫得比較大之後

| 我要… | 去哪 |
|-------|------|
| 把程式拆成模組 | [05](05-jpm-與專案.md)、[05e](05e-import-與模組路徑.md)、[`modules/`](../modules/README.md) |
| **看一個真東西怎麼分層** | ★ [`try/`](../try/README.md)——從零蓋一個 LLM 客戶端，每個決定都寫了為什麼 |
| 做出「類別」的效果 | [02b](02b-方法與-prototype.md)、[22](22-原型與方法.md)＋[`prototypes`](../examples/prototypes.janet) |
| 管理資源（開了要關）| [20b](20b-資源管理.md)＋[`errors-raii`](../examples/errors-raii.janet) |
| 寫巨集 | [08](08-巨集-macro.md)＋[`macros`](../examples/macros.janet) |
| 產生 HTML | [31](31-spork-產生-html.md) | 

> 找不到你要的？[README](README.md) 有完整目錄，
> [`reference/`](../reference/README.md) 可以查「這個領域到底有哪些函式」。
