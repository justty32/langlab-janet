# spork · 常用模組實測筆記

**這裡不是完整的 spork 文檔，也不打算是。**最完整、最新的一定是官方：

> **官方原始碼與文檔**：<https://github.com/janet-lang/spork>
> 這台機器上裝的是從該 repo 編的，manifest 記的 tag 是 `d111597`。
> 想查某個函式最快的方式其實是 REPL 裡 `(doc spork/misc/map-vals)`。

那這裡收什麼？**收官方文檔給不了你的東西**：

- **實際跑過的輸出**——每個 `=>` 右邊都是真的在 Janet 1.41.2 上跑出來的，不是照抄簽名。
- **踩到的坑**——文件沒寫、但實測會咬人的行為（下面列了幾個）。
- **中文的白話說明**——生僻名詞是什麼、什麼時候該用哪個。

概念與「該用哪個」看教學：[27 spork 全覽](../../docs/27-spork-全覽.md) 是地圖。

## 收了哪些

| 檔 | 模組 |
|----|------|
| [misc-順手工具.md](misc-順手工具.md)、[b-陣列與資料表](misc-順手工具b-陣列與資料表.md) | `misc` |
| [path-路徑.md](path-路徑.md) | `path` |
| [sh-執行外部指令.md](sh-執行外部指令.md) | `sh`、`sh-dsl` |
| [終端互動.md](終端互動.md) | `getline`、`rawterm` |
| [資料格式與驗證.md](資料格式與驗證.md) | `json`、`schema`、`data`、`infix` |
| [編碼與位元組.md](編碼與位元組.md) | `base64`、`crc`、`utf8` |
| [壓縮與封存-zip.md](壓縮與封存-zip.md) | `zip` |
| [文字比對-regex.md](文字比對-regex.md) | `regex` |
| [date-cron-日期與排程.md](date-cron-日期與排程.md) | `date`、`cron` |
| [randgen-隨機抽樣.md](randgen-隨機抽樣.md) | `randgen` |
| [並行工具-channel-ev-utils.md](並行工具-channel-ev-utils.md) | `channel`、`ev-utils` |
| [生成器與串流-generators-stream.md](生成器與串流-generators-stream.md) | `generators`、`stream` |
| [http-伺服端.md](http-伺服端.md)、[http-框架與-rpc.md](http-框架與-rpc.md) | `http`、`httpf`、`rpc`、`msg` |
| [netrepl.md](netrepl.md)、[services-與-tasker.md](services-與-tasker.md) | `netrepl`、`services`、`tasker` |
| [htmlgen-temple-產生-html.md](htmlgen-temple-產生-html.md)、[mdz-文件產生.md](mdz-文件產生.md) | `htmlgen`、`temple`、`mdz` |
| [charts-圖表.md](charts-圖表.md) | `charts` |
| [math-線性代數.md](math-線性代數.md)、[統計與機率](math-統計與機率.md)（[b](math-統計與機率b-檢定與機率分布.md)）、[數論與組合](math-數論與組合.md) | `math` |
| [tarray-cmath.md](tarray-cmath.md) | `tarray`、`cmath` |
| [程式碼工具-fmt-argparse-version.md](程式碼工具-fmt-argparse-version.md) | `fmt`、`argparse`、`version` |
| [測試工具-test.md](測試工具-test.md) | `test` |
| [pm-套件管理.md](pm-套件管理.md) | `pm` |

## 沒收哪些（刻意的）

以下模組**這個 lab 用不到**，也就沒有花力氣寫——要用直接查
[官方 repo](https://github.com/janet-lang/spork)：

| 模組 | 為什麼跳過 |
|------|-----------|
| `cc`、`declare-cc`、`build-rules`、`pm-config` | 建置工具鏈。本 repo 走 jpm 那套，看 [05c jpm 的 rule 系統](../../docs/05c-jpm-的-rule-系統.md) |
| `cjanet` | 用 Janet 語法產生 C 原始碼；手寫 native 模組看 [10d](../../docs/10d-native-與嵌入.md) |
| `gfx2d`、`gfx2d-codegen`、`gfx2d-shader` | 2D 繪圖／著色器，本 lab 沒有圖形需求 |
| `pgp` | 只有 PGP **單字表**（把 hex 指紋唸成好記的單字），不是加密 |
| `init` | 只是把所有模組 re-export 的傘狀入口，⚠ 別用，理由見 [27](../../docs/27-spork-全覽.md) |

## 實測抓到、官方文件沒明說的坑

放在這裡當索引，細節在各檔裡：

- **`json/decode` 開 `nils=true` 時 `null` 欄位會整個消失**——`{"a":null}` 變 `@{}`
  不是 `@{:a nil}`（Janet 的 table 存不了 `nil` 值，`put` nil 等於刪 key）。
- **`schema` 的 `predicate` 是巨集、`make-predicate` 是函式**。用函式版忘了 quote，
  `(make-predicate (or :number :nil))` 裡的 `or` 會先被求值成 `:number`——
  schema 悄悄變成只認數字，**完全不報錯**。
- **裸 struct 當 schema 不會逐欄位驗證**，是整包拿去 `=` 比較，幾乎必然失敗。要用 `(props …)`。
- **`regex/find-all` 找的是重疊的起點**，`"abc123"` 找 `\d+` 給你三個索引不是一段。
- **`regex` 只是把 regex 翻譯成內建 PEG**（`regex/source` 看得到翻出來的 PEG）。
- **`crc/named-variant` 只實作了幾個名字**，其餘丟 `nyi`；`:crc32` 可以、`:crc-32` 不行。
- **`date/to-string` 的格式 token 大小寫敏感**：`MM` 是月、`mm` 是分；
  `YYYY`／`DD` 不是 token，會**原樣留在輸出裡且不報錯**。
- **`channel/from-each` 沒把 channel 喝完，整個行程永遠不會結束**。
- **`zip/extract` 是附加到 `into` buffer，不會先清空**。
- **`test/skip-asserts` 跳過的 assert 仍計入總數**。
- **`misc/print-table` 遇到中文會對不齊**（欄寬按字元算，中文在終端機佔兩格）。
