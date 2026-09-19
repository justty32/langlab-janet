# 速查表（cheatsheets）

七頁**一眼掃完**的速查，從原本手寫的 `html/*.html` 逐頁轉成 markdown：GitHub 上直接能讀，
瀏覽器開 [`html/index.html`](../html/index.html)（閱讀器）看的是兩欄卡片版、可全文搜尋。
每段程式碼都在 Janet 1.41.2 跑過；地雷每條標了 `docs/` 篇號。

| 頁 | 內容 |
|----|------|
| [核心](核心.md)（＋[核心b](核心b.md) 地雷合輯） | 語言核心・括號家族・資料結構・印與除錯・jpm/REPL |
| [資料 / IO](資料與-io.md) | spork/json・spork/argparse・檔案讀寫・marshal 序列化 |
| [PEG](peg.md) | Janet 內建的解析器：比 regex 強，能解巢狀 |
| [並行](並行.md) | fiber・ev・channel・真執行緒・net・子行程與信號 |
| [C 互通](c-互通.md) | FFI・指標與記憶體・native 模組・把 Janet 嵌進 C |
| [env / 符號](env-與符號.md) | 環境表・動態變數・symbol↔字串・巨集・自省 |
| ★ [地雷](地雷.md) | 「這行為怪怪的，是不是已知的坑？」——全部實測過，每條標了出處 |

拆成多頁是為了每頁都還能一眼掃完；要全文搜尋用閱讀器，或 `grep -r cheatsheets/`。
完整說明在 [`docs/`](../docs/README.md)，查「有哪些可用」在 [`reference/`](../reference/README.md)。
