# spork/misc ・ 順手工具（上：控制流／雜項／字串轉換）

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/misc` 是一包「內建沒有、但常用得到」的雜項函式，總共 42 個，本檔收「控制流巨集」
「雜項工具」「字串／整數轉換」21 個；陣列排序搜尋、資料表（data-frame）另收在
[misc-順手工具b-陣列與資料表.md](misc-順手工具b-陣列與資料表.md)。全部用 `(import spork/misc :prefix "")`
去掉前綴後測過，實際使用時前綴看個人喜好（不去也行，寫成 `misc/xxx`）。

## 控制流巨集

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `always` | `(always x)` | 回傳一個「不管給什麼參數都回傳 `x`」的函式 |
| `until` | `(until cnd & body)` | `while` 的反向版：條件為**真**才停 |
| `cond->` | `(cond-> val & clauses)` | 依序檢查 `條件 操作` 這對 pair，條件為真就把 `val` 餵給操作、更新 `val`，最後回傳 |
| `cond->>` | `(cond->> val & clauses)` | 同 `cond->`，但 `val` 放在操作的**最後**一個參數 |
| `defs` | `(defs & bindings)` | 一次 `def` 多個常數，語法跟 `let` 的 bindings 一樣，但不開新作用域 |
| `vars` | `(vars & bindings)` | 同 `defs`，但用 `var`（可變） |
| `do-def` | `(do-def c d & body)` | 先 `(def c d)`、跑 `body`（通常拿 `c` 這個容器去改）、回傳 `c` |
| `do-var` | `(do-var v d & body)` | 同 `do-def`，但用 `var` |
| `set*` | `(set* tgts exprs)` | 平行版 `set`：先算完所有 `exprs` 再一起賦值給 `tgts`（可互換變數值不用暫存） |
| `dfs` | `(dfs data visit-leaf &opt node-before node-after get-children seen)` | 對任意資料結構做深度優先前序走訪，可自訂子節點取法、可偵測環狀引用 |

## 雜項工具

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `caperr` | `(caperr & body)` | 執行 `body`，把它印到 stderr 的內容截下來變成 buffer 回傳 |
| `capout` | `(capout & body)` | 同 `caperr`，截的是 stdout |
| `log` | `(log level & args)` | 印到 `(dyn level)` 這個動態變數指到的 stream，沒設就什麼都不做（安靜失敗，不報錯） |
| `dedent` | `(dedent & xs)` | 接起多個字串後，把每行開頭共同的縮排去掉（常用在多行字串常數） |
| `make` | `(make prototype & kvpairs)` | 用 `kvpairs` 建一個新 table，並把 `prototype` 設成它的原型（見 `reference/` 對應原型教學 docs/22） |
| `make-id` | `(make-id &opt prefix)` | 產生帶隨機亂數（10 bytes 熵）的 keyword id，可加前綴 |

## 字串／整數轉換

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `int->string` | `(int->string int &opt base)` | 整數轉字串，可指定進位（預設 10 進位） |
| `string->int` | `(string->int str &opt base)` | 字串轉整數，只認整數不認小數點（跟內建 `scan-number` 不同） |
| `int/` | `(int/ & xs)` | 整數除法，**朝零捨去**（不是無條件捨去） |
| `trim-prefix` | `(trim-prefix prefix str)` | 有這個前綴就去掉，沒有就原樣回傳 |
| `trim-suffix` | `(trim-suffix suffix str)` | 同上，去尾綴 |

## 實測範例

```janet
(import spork/misc :prefix "")

(def f (always 5))
(f 1 2 3)  # => 5     不管給幾個參數都回 5
(f)        # => 5

(var i 0)
(until (= i 3) (print i) (++ i))
# 依序印出 0 1 2

(cond-> 1
  true  inc     # 1 -> 2
  false inc     # 條件假，跳過
  true  (* 10)) # 2 -> 20
# => 20

(var a 1) (var b 2)
(set* [a b] [b a])
[a b]  # => (2 1)   交換成功，不用暫存變數
```

⚠ `dfs` 的走訪順序是**前序**（先訪問節點本身，才遞迴進子節點）：

```janet
(def acc @[])
(dfs [1 [2 3] 4] (fn [x] (array/push acc x)))
acc  # => @[1 2 3 4]
```

```janet
(capout (print "hi"))          # => @"hi\n"
(caperr (eprint "oops"))       # => @"oops\n"

(log :err "不會印出來，因為 (dyn :err) 沒設定")
(setdyn :err stdout)
(log :err "現在會印：%d" 42)   # => 現在會印：42

(dedent "  hello\n  world")
# => "hello\nworld"   共同的兩格縮排被去掉

(def proto @{:greet (fn [self] (print "hi " (self :name)))})
(def o (make proto :name "Bob"))
(:greet o)  # => hi Bob

(make-id)          # => :96A79DC80CC1FF246294  （每次跑都不同，10 bytes 隨機熵）
(make-id "user-")  # => :user-A8CACADE2343CBDB0CA6

(int->string 255 16)  # => "ff"
(string->int "ff" 16) # => 255
(int/ 7 2)             # => 3
(int/ -7 2)            # => -3    朝零捨去，不是 -4（floor 的話會是 -4）

(trim-prefix "foo-" "foo-bar")  # => "bar"
(trim-prefix "foo-" "bar")      # => "bar"    沒有這個前綴就原樣回傳
(trim-suffix ".txt" "a.txt")    # => "a"
```
