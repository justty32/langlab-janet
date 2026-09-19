# 我要做 X，去哪 · 資料、排錯、寫大一點

[← 我要做 X，去哪](怎麼做-X.md)｜[docs 目錄](README.md)

[怎麼做-X](怎麼做-X.md) 的後半：資料處理、出問題時往哪查、程式寫大之後的招。
三欄的意思一樣：**教學**＝為什麼與觀念、**可跑**＝直接跑起來看、**抄**＝貼進你的專案改。

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
| 產生 HTML | [31](31-spork-產生-html.md)＋[`spork-tour`](../examples/spork-tour.janet) |

> **想確認自己真的懂了** → [`exercises/`](../exercises/README.md)：題目專挑 ⚠ 陷阱，
> 跑起來會告訴你第幾題錯、預期什麼、你給了什麼。
>
> 找不到你要的？[README](README.md) 有完整目錄，
> [`reference/`](../reference/README.md) 可以查「這個領域到底有哪些函式」。
