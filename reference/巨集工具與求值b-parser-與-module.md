# parser 與 module ・ 全部 28 個

[← reference 索引](README.md)｜[← 巨集工具與求值](巨集工具與求值.md)

對應教學：[05e import 與模組路徑](../docs/05e-import-與模組路徑.md)、
[08 巨集](../docs/08-巨集-macro.md)、[07 repl](../docs/07-repl.md)。

> 對著 `root-env` 逐一核過，共 28 個：`parser/*` 13 ＋ `module/*` 10 ＋
> 載入用的 5 個（`require` `import` `import*` `use` `merge-module`）。

## `parser/*`（13 個）

一台狀態機：餵 bytes 進去，吐值出來。`parse`／`eval-string` 是它的簡化包裝，
要「邊讀邊剖析」「知道錯在第幾行」「REPL 的續行提示」才需要直接用。

| 函式 | 簽名 | 說明 |
|------|------|------|
| `parser/new` | `(parser/new)` | 開一台，型別是 `:core/parser` |
| `parser/consume` | `(parser/consume p bytes &opt index)` | 餵一段 bytes，回**讀了幾個 byte**；有語法錯也不丟例外 |
| `parser/byte` | `(parser/byte p b)` | 餵**一個** byte（數字），回 parser |
| `parser/insert` | `(parser/insert p value)` | 直接塞一個**值**進去，繞過 bytes |
| `parser/produce` | `(parser/produce p &opt wrap)` | 取出下一個完成的值；佇列空回 `nil`。`wrap` 為真時包成 1 元 tuple，給 source-map 用 |
| `parser/has-more` | `(parser/has-more p)` | 佇列裡還有沒有值 |
| `parser/status` | `(parser/status p)` | `:pending`／`:error`／`:root`／`:dead` |
| `parser/error` | `(parser/error p)` | 錯誤訊息，沒錯回 `nil`。⚠ **會順手 flush 掉狀態與佇列** |
| `parser/eof` | `(parser/eof p)` | 告訴它檔案到底了，進 `:dead` |
| `parser/flush` | `(parser/flush p)` | 清狀態與佇列；⚠ **行號欄號不會歸零** |
| `parser/where` | `(parser/where p &opt line col)` | 回 `(行 欄)`，也可以直接設定 |
| `parser/state` | `(parser/state p &opt key)` | `:delimiters`（還沒閉合的括號字串）與 `:frames` |
| `parser/clone` | `(parser/clone p)` | 深拷貝，當作 checkpoint |

```janet
(def p (parser/new))
(parser/consume p "(+ 1 2) 5")   # => 9
(parser/produce p)               # => (+ 1 2)
(parser/status p)                # => :pending
(parser/has-more p)              # => false
```

⚠ 上面 `5` 取不到——**最後一個 token 沒有結束符時還算「正在剖析」**，
要再餵一個空白或呼叫 `parser/eof` 它才會進佇列。

錯誤與續行：

```janet
(def q (parser/new))
(parser/consume q "1)")          # => 2
(parser/status q)                # => :error
(parser/error q)                 # => "unexpected closing delimiter )"
```

```janet
(def r (parser/new))
(parser/consume r "(1 2")        # => 4
(parser/state r :delimiters)     # => "("
(parser/flush r)
(parser/status r)                # => :root
```

`:delimiters` 就是 REPL 拿來畫續行提示的東西。沒閉合就丟 `parser/eof`，
錯誤訊息會告訴你那個括號是在哪開的：`unexpected end of source, ( opened at line 1, column 1`。

## `module/*`（10 個）

| 名 | 型別 | 說明 |
|----|------|------|
| `module/paths` | array | 搜尋樣板清單，每項是 `[樣板 種類 過濾器]`；這台機器上 21 項 |
| `module/loaders` | table | 種類 → 載入函式。四種：`:source` `:native` `:image` `:preload` |
| `module/cache` | table | 已載入模組 → 它的 env；`require` 第二次直接回快取 |
| `module/loading` | table | 正在載入中的模組，用來擋循環依賴 |
| `module/find` | `(module/find path &opt find-all)` | 回 `(完整路徑 種類)`，找不到回 `(nil 錯誤訊息)`——**不丟錯** |
| `module/expand-path` | `(module/expand-path path template)` | 把樣板裡的 `:all:` `:cur:` `:dir:` `:name:` `:native:` `:sys:` `:@all:` 換掉 |
| `module/add-paths` | `(module/add-paths ext loader)` | 為某副檔名補一整組樣板（相對、syspath、專案相對都有）|
| `module/add-file-extension` | `(module/add-file-extension ext loader)` | 只讓「相對／絕對路徑直接 import」這種用法生效 |
| `module/add-syspath` | `(module/add-syspath path)` | 把所有 `:sys:` 開頭的樣板複製一份，換成指定前綴 |
| `module/value` | `(module/value module sym &opt private)` | 從 env table 取值；預設**取不到私有綁定** |

```janet
(module/expand-path "foo" ":all:.janet")            # => @"foo.janet"
(module/expand-path "foo/bar" ":dir:/:name:.janet") # => @"foo/bar.janet"
(distinct (map |(get $ 1) module/paths))            # => @[:preload :native :source :image]
(sort (keys module/loaders))                        # => @[:image :native :preload :source]
```

⚠ `module/expand-path` 回的是 **buffer**（`@"…"`）不是 string。
`:sys:` 會展開成 `(dyn :syspath)`，所以輸出跟你這台機器的安裝路徑有關。

## 載入（5 個）

| 名 | 是什麼 | 說明 |
|----|--------|------|
| `require` | 函式 | `(require path & args)`，回模組的 env table；走 `module/cache` |
| `import` | 巨集 | 名字不用引號，展開成 `import*` |
| `import*` | 函式 | `(import* path & args)`，路徑與選項都是**字串** |
| `use` | 巨集 | `(use foo)` = `(import* "foo" :prefix "")`，全部倒進當前 env |
| `merge-module` | 函式 | `(merge-module target source &opt prefix export only)`，手動做 `import` 做的事 |

選項：`:as` `:prefix` `:export` `:only` `:fresh`。

```janet
(macex1 ~(import foo :as f))   # => (<function import*> "foo" :as "f")
(macex1 ~(use foo))            # => (do (<function import*> "foo" :prefix ""))
```

⚠ `(require "./mod")` 對同一個檔案跑兩次回的是**同一張 env table**（`module/cache`），
所以改了檔案要重載得加 `:fresh true` 或自己清 cache。私有綁定（`defn-`）
`import` 不會帶過去，但 `(module/value env 'name true)` 拿得到。
