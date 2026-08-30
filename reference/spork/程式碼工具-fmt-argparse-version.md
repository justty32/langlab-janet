# 程式碼工具 ・ fmt／argparse／version

[← spork 索引](README.md)｜[← reference 索引](../README.md)

fmt 是原始碼自動排版器（像其他語言的 `gofmt`／`prettier`）；argparse 是命令列參數解析；
version 單純回報 spork 自己的版本號。測試框架 `spork/test`（20 個綁定）另見
[測試工具-test.md](測試工具-test.md)。

## fmt

| 函式 | 簽名 | 說明 |
|---|---|---|
| `fmt/format` | `(format source)` | 原始碼字串 → 排版後的字串（buffer） |
| `fmt/format-print` | `(format-print source)` | 排版後直接印到 stdout |
| `fmt/format-file` | `(format-file file)` | **原地**排版一個檔案（會覆寫！） |
| `fmt/*user-indent-2-forms*` | （keyword，非函式） | 一份「視為 control form、要縮排兩格」的表單名單，可自訂擴充 |

```janet
(import spork/fmt)
(fmt/format-print "(defn   foo [x   y]  (+ x y))")
# => (defn foo [x y] (+ x y))

(fmt/format "(  def a    1)")
# => @"(def a 1)\n"
```

實測 `format-file`（對一個內容為 `(defn   foo [x   y]\n  (+ x    y))` 的檔案跑過）：
排版後變成

```janet
(defn foo [x y]
  (+ x y))
```
多餘空白被收乾淨、換行位置照 Janet 慣例排版。**這個函式會直接覆寫原檔，沒有 dry-run 選項**，
要保留原檔先自己複製一份。

## argparse

| 函式 | 簽名 | 說明 |
|---|---|---|
| `argparse/argparse` | `(argparse description &keys options)` | 解析 `(dyn :args)`，依 `options` 描述的每個選項回傳結果 table；參數不合法會印用法說明並回傳 `nil` |

每個選項是一個 table，`:kind` 決定型態：`:flag`（開關）、`:multi`（可重複出現，累加成整數）、
`:option`（吃一個值）、`:accumulate`（可重複出現，每次的值收進陣列）。特殊名字 `:default` 收集
「沒有 `--`／`-` 開頭」的位置參數。

```janet
(import spork/argparse)
(setdyn :args @["prog" "--name" "world" "-v" "extra1" "extra2"])
(argparse/argparse "demo"
  "name" {:kind :option :short "n" :help "your name"}
  "verbose" {:kind :flag :short "v" :help "verbose mode"}
  :default {:kind :accumulate :help "positional args"})
# => @{"name" "world" "verbose" true :default @["extra1" "extra2"]
#      :order @["name" "verbose" :default :default]}
```
回傳的 table 用選項名字（字串）當 key 取值，另外附一個 `:order` 記錄選項出現的順序。

## version

| 綁定 | 型別 | 說明 |
|---|---|---|
| `version/parts` | tuple | spork 版本號拆成 `(major minor patch)` |
| `version/text` | string | spork 版本號字串 `"major.minor.patch"` |

```janet
(import spork/version)
version/parts   # => (1 0 1)
version/text    # => "1.0.1"
```
純資料，不是函式，直接取值就好。這台機器上裝的 spork 是 1.0.1。
