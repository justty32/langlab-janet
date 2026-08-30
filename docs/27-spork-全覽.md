# 27 · spork 全覽

`spork` 是 Janet 的**準標準庫**——不是內建（`janet` 執行檔裡沒有），但幾乎人人都裝，
官方維護，`jpm install spork` 就有。這台機器上共 **51 個模組、706 個公開綁定**。

> ⚠ 版本號有兩個說法：`(import spork/version)` 的 `version/text` 說 **1.0.1**，
> 但 jpm 的 manifest 記的是 **1.2.0**。前者是庫自己寫死的常數、後者是 jpm 裝的時候記的，
> 要對版本請以 manifest 的 git tag 為準（這台是 `d111597`）。

這篇是**地圖**：先讓你知道有哪些東西、怎麼挑、怎麼 import。
常用模組的實測筆記在 [`reference/spork/`](../reference/spork/README.md)；
**完整清單一律以[官方 repo](https://github.com/janet-lang/spork) 為準**，或在 REPL 裡 `(doc spork/misc/map-vals)`。

## 先講 import：不要 `(import spork)`

```janet
(import spork/json)            # ✔ 要哪個拿哪個
(import spork/path :as p)      # ✔ 取個短名
(import spork)                 # ✘ 幾乎不要這樣
```

`spork/init.janet` 的內容就是把每個模組 `(import ./xxx :export true)` 一遍。所以
`(import spork)` 會**把全部東西倒進你的環境**——實測 `(curenv)` 的綁定數從
**702 變成 1409**，等於憑空多出七百個你沒打算要的名字。後果是：

- 你的名字很容易跟它撞，而且撞了不會有警告，只是行為變得莫名其妙。
- 補全清單爆炸，`(doc ...)` 也難查。

⚠ 例外只有一個：在 REPL 裡隨手玩、想少打幾個字時無所謂。**寫進檔案的一律逐個 import。**

> 好消息：**每個模組 import 時都是安靜的**（實測 15 個常用模組，沒有一個印東西或有副作用），
> 所以逐個 import 不會有意外。

## 純 Janet vs 原生模組（這關係到一個大坑）

51 個模組裡有 **9 個是原生模組**（C 寫的 `.so`）：

```
base64  cmath  crc  gfx2d  json  rawterm  tarray  utf8  zip
```

其餘 42 個是純 `.janet` 檔。差別在**能不能順利裝起來**：

⚠ **純 `.janet` 檔照抄就好，原生模組要編、要能寫進去。**在 Windows 上，只要有
REPL 或 LSP 正載入著某個 `.so`，`jpm install spork` 會**靜默失敗**——exit 0、
一行輸出都沒有、manifest 還說裝好了，但那 9 顆一顆都沒進去。
完整的症狀與安全修法見 [FINDINGS-踩坑b-工具鏈.md](../FINDINGS-踩坑b-工具鏈.md) 第十二節。

> **判斷方式**：`jpm install X` 沒有輸出 **≠** 成功。一律用 `janet -e '(import spork/utf8)'` 驗收。
> 這也是為什麼 `modules/llm-http/media.janet`（用到 `spork/base64`）在沒補齊的機器上整支跑不起來。

## 地圖：51 個模組分成七類

| 類別 | 模組 | 什麼時候想到它 |
|------|------|----------------|
| **資料格式** | `json` `data` `schema` `infix` | 讀寫 JSON、比對兩份資料的差異、驗證輸入的形狀 |
| **編碼與壓縮** | `base64` `crc` `zip` `utf8` `pgp` | 圖片轉 data URI、算校驗碼、壓縮、按「字元」處理中文 |
| **文字處理** | `regex` `temple` `htmlgen` `mdz` `fmt` | 比對字串、套模板產 HTML、格式化 Janet 程式碼 |
| **系統與檔案** | `path` `sh` `sh-dsl` `getline` `rawterm` `misc` | 組路徑、跑外部指令、做互動式 CLI、各種順手工具 |
| **時間與亂數** | `date` `cron` `randgen` | 日期運算、排程運算式、加權抽樣與常態分布 |
| **並行與網路** | `channel` `ev-utils` `generators` `stream` `msg` `http` `httpf` `rpc` `netrepl` `services` `tasker` | 平行處理、串流、HTTP client/server、遠端 REPL、背景工作 |
| **數值與建置** | `math` `cmath` `tarray` `cc` `cjanet` `declare-cc` `build-rules` `pm` `pm-config` `charts` `gfx2d*` `test` `version` | 線性代數、型別化陣列、編 C、寫套件、畫圖表、輔助測試 |

**這張表是給「我大概要做 X，有現成的嗎」用的。**確定了模組再去
[`reference/spork/`](../reference/spork/README.md) 看實測筆記，或直接查官方。

## 已經有專篇教學的五個

這五個在本 repo 用得最兇，各自有一整篇：

| 模組 | 教學 | 一句話 |
|------|------|--------|
| `spork/json` | [03 JSON](03-json.md) | `encode`／`decode`、null 陷阱、`keywords` 參數 |
| `spork/argparse` | [04 CLI 參數](04-cli-argparse.md) | 四種 kind、自動 help、子命令 |
| `spork/http` | [17 用 spork/http 打 API](17-用-spork-http-打-api.md) | POST 寫法、buffer／status 兩個雷、沒 TLS 沒串流 |
| `spork/path` | [19b 檔案系統與路徑](19b-檔案系統與路徑.md) | 組路徑不要自己接字串 |
| `spork/sh` | [11 子行程／管線／信號](11-pipeline-signal.md) | `exec-slurp` 與內建 `os/execute` 的分工 |

## 「我要做 X」→ 用哪個

| 你想做的事 | 先看 |
|------------|------|
| 讀寫 JSON | `spork/json`（[03](03-json.md)） |
| 驗證使用者傳進來的資料形狀 | `spork/schema` |
| 比對兩份資料差在哪 | `spork/data` 的 `diff` |
| 按「字元」而不是 byte 處理中文 | `spork/utf8`（[18](18-字串與-buffer.md) 講了為什麼需要它） |
| 圖片／二進位轉成可放進 JSON 的字串 | `spork/base64` |
| 跑外部指令並拿到輸出 | `spork/sh` 的 `exec-slurp`（[11](11-pipeline-signal.md)） |
| 組路徑（跨平台） | `spork/path`（[19b](19b-檔案系統與路徑.md)） |
| 日期加減、格式化 | `spork/date`；只要時間戳的話內建就夠（[24](24-時間與日期.md)） |
| 「每週一早上八點」這種排程 | `spork/cron` |
| 加權隨機、常態分布抽樣 | `spork/randgen`（基本亂數看 [26](26-隨機數.md)） |
| 平行跑一堆工作 | `spork/ev-utils` 的 `pmap`（fiber 概念看 [09](09-fiber.md)） |
| 起一台 HTTP server | `spork/http`／`spork/httpf`（[17](17-用-spork-http-打-api.md)） |
| 產生 HTML | `spork/htmlgen`（用 Janet 資料結構寫）或 `spork/temple`（模板） |
| 格式化我的 Janet 程式碼 | `spork/fmt` |
| 寫測試的輔助工具 | `spork/test`（測試怎麼寫看 [23](23-測試怎麼寫.md)） |
| 用 Janet 產生 C 原始碼 | `spork/cjanet`（手寫 C 模組看 [10d](10d-native-與嵌入.md)） |

## 可跑範例

```sh
janet examples/spork-tour.janet    # 十四個模組各跑一段，一次看完 spork 能幹嘛
```

常用模組的實測筆記：[`reference/spork/`](../reference/spork/README.md)。
完整而最新的 API 清單在[官方 repo](https://github.com/janet-lang/spork)。

下一步：[28-spork-misc-順手工具.md](28-spork-misc-順手工具.md)。
