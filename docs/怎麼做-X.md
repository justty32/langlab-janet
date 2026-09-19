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
| **Ctrl-C／SIGTERM 時優雅收尾** | [11](11-pipeline-signal.md)、[20b](20b-資源管理.md) | — | ★ [`graceful-shutdown`](../snippets/graceful-shutdown.janet) |
| 跑完掉進 REPL 讓人手動探索 | [07](07-repl.md) | — | [`repl-mode`](../snippets/repl-mode.janet) |
| 編成單一執行檔 | [05c](05c-jpm-的-rule-系統.md)、[16d](16d-image-與-jpm.md) | — | — |
| 把程式編成 `.jimage`、或跑到一半存下來下次續跑 | [16b](16b-image-存成檔.md)、[16c](16c-image-怎麼用.md) | [`image-tour`](../examples/image-tour.janet) | ★ [`checkpoint/`](../snippets/checkpoint/main.janet) |

## 從別的語言搬過來

| 我要… | 教學 | 可跑 | 抄 |
|-------|------|------|-----|
| 寫 return／break／continue／跳出巢狀迴圈 | [01d](01d-提早離開-return-break-continue.md) | [`early-exit`](../examples/early-exit.janet) | — |
| 把 C／C++ 的寫法對到 Janet | [43](43-從-C-C++-過來.md) | [`compare-c`](../examples/compare-c.janet) | — |
| 把 Lua 的寫法對到 Janet | [44](44-從-Lua-過來.md) | [`compare-lua`](../examples/compare-lua.janet) | — |
| 把 Go 的寫法對到 Janet | [45](45-從-Go-過來.md) | [`compare-go`](../examples/compare-go.janet) | — |
| 把 Python 的寫法對到 Janet | [46](46-從-Python-過來.md) | [`compare-python`](../examples/compare-python.janet) | — |

整組的索引（含 43b／43c／44b／45b／46b–46f）在
[從別的語言過來](從別的語言過來-索引.md)。

## 跟外面打交道

| 我要… | 教學 | 可跑 | 抄 |
|-------|------|------|-----|
| 跑外部命令、接管線 | [11](11-pipeline-signal.md)、[41](41-spork-終端與-shell.md) | [`pipeline`](../examples/pipeline.janet)、[`term-shell`](../examples/term-shell.janet) | [`pipe-to-child`](../snippets/pipe-to-child/) |
| 打 HTTP API | [17](17-用-spork-http-打-api.md) | — | [`http-local`](../snippets/http-local/main.janet) |
| 打 LLM | [47](47-llm-api-是什麼.md)（七篇從零學）| [`examples/agent-tutorial/`](../examples/agent-tutorial/README.md)、[`examples/llm-http/`](../examples/llm-http/README.md) | [`modules/llm-http/`](../modules/llm-http/README.md) |
| **做一個能讀檔、算數、抓網頁的 agent** | [47d](47d-自己寫-agent-loop.md) | [`examples/agent/`](../examples/agent/README.md) | ★ [`modules/agent/`](../modules/agent/README.md) |
| 串流輸出／直打 https／Anthropic 原生 | — | [`examples/llm-http/`](../examples/llm-http/README.md) | [`streaming`](../modules/llm-http/doc/streaming.md)、[`https-與-curl`](../modules/llm-http/doc/https-與-curl.md)、[`anthropic-原生`](../modules/llm-http/doc/anthropic-原生.md) |
| **重試與逾時** | [15](15-ev-channel-net.md) | — | ★ [`retry-timeout`](../snippets/retry-timeout.janet) |
| **並行跑一批工作（限流、單一失敗不拖垮）** | [30](30-spork-並行與服務.md) | — | ★ [`parallel-batch`](../snippets/parallel-batch.janet) |
| 判斷作業系統、處理跨平台 | [39](39-跟作業系統打交道.md) | [`os-tour`](../examples/os-tour.janet) | — |
| 呼叫 C 函式庫 | [10](10-c-互通.md)、[10b](10b-ffi-型別與指標.md) | [`ffi-demo`](../examples/ffi-demo.janet)、[`ffi-pointers`](../examples/ffi-pointers.janet) | — |

## 剩下的三區在後半

[**我要做 X · 資料、排錯、寫大一點**](怎麼做-X-b-資料與排錯.md)——
處理資料（map／排序／PEG／時間／亂數）、出問題的時候（讀錯誤、量效能、查型別）、
寫得比較大之後（拆模組、prototype、資源管理、巨集、產 HTML）。

> 找不到你要的？[README](README.md) 有完整目錄，
> [`reference/`](../reference/README.md) 可以查「這個領域到底有哪些函式」。
