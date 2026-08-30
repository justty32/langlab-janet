# 41 · spork 終端與 shell

寫 CLI 工具時會用到的三個 spork 模組：**`sh-dsl`**（像 shell 那樣串管線）、
**`rawterm`**（終端機寬度與按鍵）、**`getline`**（可編輯的輸入行）。

[11 子行程](11-pipeline-signal.md) 講的是內建的 `os/execute`／`os/spawn`；
這篇講「同樣的事寫起來能多短」，以及**中文表格對齊**那個一直沒解的問題。

## 一、`sh-dsl`：`|` 真的能當管線用

```janet
(import spork/sh-dsl :as sh)

(sh/$   echo hi)                    # => 0        跑，回 exit code（輸出直接印出去）
(sh/$<  echo hi)                    # => @"hi\n"  跑，回最後一個命令的 stdout
(sh/$<_ echo hi)                    # => @"hi"    同上，去掉尾端換行
(sh/$?  false)                      # => false    只問成功了沒

(sh/$<_ printf "b\na\n" | sort)     # => @"a\nb"  ⚠ | 在這裡真的是管線
```

⚠ **`|` 平常是短函式**（`|(+ $ 1)`，見 [33](33-函式參數與閉包.md)）。
這幾個是巨集，在它們的參數位置裡 `|` 被重新詮釋成管線分隔——**只在這裡成立**。

### ⚠ `$<` 回的是 buffer，不是 string

```janet
(type (sh/$< echo hi))       # => :buffer
(= "hi" (sh/$<_ echo hi))    # => false      ⚠ buffer ≠ string（見 [13](13-symbol-keyword-字串.md)）
(string (sh/$<_ echo hi))    # => "hi"       要比較、要當 key 就先轉
```

### 失敗要不要拋錯：`*errexit*`

預設**不拋**，跟 shell 的預設一樣：

```janet
(sh/$ false)                                    # => 1，程式繼續跑

(with-dyns [sh/*errexit* true] (sh/$ false))
# error: non-zero exit code 1
```

`*errexit*` 與 `*pipefail*` 是 `defdyn` 定義的動態變數（見 [40](40-內建動態變數.md)），
所以可以用 `with-dyns` 只在一個區塊裡開。

### 三個跑外部命令的方式，怎麼挑

| | 回什麼 | 經過 shell？ | 什麼時候用 |
|---|--------|-------------|-----------|
| `os/execute` | **乾淨的 exit code** | ✘ | 要判斷成敗、參數含空白或引號時（[11](11-pipeline-signal.md)）|
| `os/shell` | ⚠ **exit code × 256** | ✓ | 「跑一下、不管結果」（[39](39-跟作業系統打交道.md)）|
| `sh-dsl` 的 `$`／`$<` | exit code／stdout buffer | ✘（自己接管線）| 要**串管線**又想寫得短 |

`sh-dsl` 不經過 shell，所以**不用煩惱引號跳脫**，但也代表 `*`、`>` 這些 shell 展開不會發生。

## 二、`rawterm`：★ 中文表格終於對得齊

[28b](28b-spork-misc-文字與流程.md) 記了一個沒解的問題：印表格時**中文會對不齊**，
因為欄寬按字元數算，但中文字在終端機佔**兩格**。`rawterm/monowidth` 就是缺的那塊：

```janet
(import spork/rawterm)

(rawterm/monowidth "abc")       # => 3
(rawterm/monowidth "中文")      # => 4     ← 兩個字、四格寬
(rawterm/monowidth "中文abc")   # => 7
(length "中文abc")              # => 9     ⚠ length 給的是 byte 數
```

三個數字全都不一樣：**byte 數 ≠ 字元數 ≠ 顯示寬度**。用 `%-10s` 排版時 printf 數的是
byte，所以中文欄一定歪。自己補空白就對了：

```janet
(defn pad [s w]
  (string s (string/repeat " " (max 0 (- w (rawterm/monowidth s))))))
```

實測前後對照（框線自己看）：

```
用 length 排版        用 monowidth 補
|abc       |          |abc       |
|中文    |            |中文      |
|中文abc |            |中文abc   |
```

其他好用的：

| 函式 | 用途 |
|------|------|
| `(rawterm/size)` | `[列 行]`——畫進度條、決定要不要截斷時要它。⚠ 見下 |
| `(rawterm/isatty)` | 跟 `os/isatty` 同義（[39](39-跟作業系統打交道.md)）|
| `(rawterm/slice-monowidth s w)` | 按**顯示寬度**切字串，不會把中文切一半 |
| `(rawterm/getch)` | 讀單一按鍵，不用等 Enter |
| `(rawterm/begin)` / `(rawterm/end)` | 進出 raw mode |

### ⚠ `rawterm/size` 在非終端機下回的是垃圾，不是錯誤

實測三種情況：

| 環境 | `(rawterm/size)` |
|------|-----------------|
| 設好大小的真終端機（40 列 120 行）| `(40 120)` ✓ |
| 沒設大小的 pty | `(0 0)` |
| **輸出被導走（`\| cat`、`> 檔案`）** | **`(33328 12534)` 之類的隨機值**，每次跑都不同 |

它不會報錯、也不會回 `nil`——**直接給你未初始化的記憶體內容**。所以：

```janet
(def [列 行] (if (rawterm/isatty) (rawterm/size) [24 80]))
(def 行 (if (pos? 行) 行 80))     # 0 也要當成「不知道」
```

**先問 `isatty`，再把 0 當成未知**，兩道都要。

### ⚠ raw mode 一定要收尾

**`begin` 之後終端機就不回顯、不處理 Ctrl-C 了**，一定要用
[`defer`／`with`](20b-資源管理.md) 保證 `end` 會被呼叫——忘了收尾的話你的 shell 會壞掉，
要打 `reset` 才救得回來。

## 三、`getline`：可編輯的輸入行

內建的 `(getline)` 只是「讀一行」。`spork/getline` 的 `make-getline` 給你
**歷史紀錄、Tab 補全、文件提示**——Janet 自己的 REPL 就是用它做的。

```janet
(import spork/getline)
(def 讀一行 (getline/make-getline))
(讀一行 "> " @"")      # 提示字元、緩衝區
```

它是互動的、寫不進自動測試，所以本 repo 只記到這裡。

## 沒收的：`charts`

`spork/charts` 能畫折線圖／熱力圖，但它回的是 **`gfx2d/image`**——
要另一個原生模組 `gfx2d` 才能存檔或顯示。那超出「純 Janet 玩得動」的範圍，
本 repo 不收（理由同 [`reference/spork/README`](../reference/spork/README.md) 的「刻意沒收」）。

## 可跑範例

`janet examples/term-shell.janet`——中文對齊的前後對照、`sh-dsl` 的四個形式、
`rawterm/size` 在非終端機下的垃圾值都印得出來。

清單見 [`reference/spork/終端互動.md`](../reference/spork/終端互動.md)；
下一步：回 [主題與 spork 索引](主題與-spork-索引.md)。
