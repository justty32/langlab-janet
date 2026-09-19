# 核心巨集全表 ・ 全部 86 個

[← reference 索引](README.md)｜[← 特殊形式與判定方法](特殊形式與核心巨集.md)

> 對著 `root-env` 逐一核過——`(get (get root-env k) :macro)` 為真的**剛好 86 個**，
> 下面十四組加起來一個不多一個不少。已經有專屬文檔的那幾組只列名字並連過去，
> 不在這裡重講。

## 一眼表

| 組 | 幾個 | 成員 | 細節在哪 |
|----|------|------|----------|
| 定義 | 9 | `defn` `defn-` `defmacro` `defmacro-` `varfn` `def-` `var-` `defdyn` `default` | [特殊形式與核心巨集](特殊形式與核心巨集.md) |
| 綁定 | 3 | `let` `with-syms` `with-vars` | 同上 |
| 編譯期 | 5 | `comptime` `compif` `compwhen` `as-macro` `chr` | 同上 |
| 條件 | 12 | `and` `or` `when` `unless` `if-not` `cond` `case` `match` `if-let` `when-let` `if-with` `when-with` | [控制流](控制流.md) |
| 迴圈 | 12 | `loop` `each` `eachk` `eachp` `for` `forv` `forever` `repeat` `seq` `tabseq` `catseq` `generate` | [控制流](控制流.md) |
| 錯誤與資源 | 7 | `try` `protect` `defer` `edefer` `with` `assert` `assertf` | [斷言與錯誤](斷言與錯誤.md) |
| 執行緒巨集 | 7 | `->` `->>` `-?>` `-?>>` `as->` `as?->` `juxt` | 本頁下方 |
| 數值就地更新 | 8 | `++` `--` `+=` `-=` `*=` `/=` `%=` `toggle` | 本頁下方 |
| 跳出 | 2 | `label` `prompt` | [控制流](控制流.md) |
| 模組 | 2 | `import` `use` | [巨集工具與求值b](巨集工具與求值b-parser-與-module.md) |
| fiber／ev | 10 | `fiber-fn` `coro` `ev/spawn` `ev/gather` `ev/do-thread` `ev/spawn-thread` `ev/with-deadline` `ev/with-lock` `ev/with-rlock` `ev/with-wlock` | [fiber 與 ev](fiber-與-ev.md) |
| ffi | 2 | `ffi/defbind` `ffi/defbind-alias` | [ffi 全表](ffi-全表.md) |
| 動態變數／env | 2 | `with-dyns` `with-env` | [40](../docs/40-內建動態變數.md)、[12b](../docs/12b-切換-env.md) |
| 其他 | 5 | `comment` `delay` `short-fn` `doc` `tracev` | 本頁下方 |

## 執行緒巨集（7 個）

| 名 | 插在哪 | 斷在哪 |
|----|--------|--------|
| `->` | 每一步的**第一個**參數 | 不斷 |
| `->>` | 每一步的**最後一個**參數 | 不斷 |
| `-?>` | 同 `->` | 中途出現 `nil` 就整串回 `nil` |
| `-?>>` | 同 `->>` | 同上 |
| `as->` | 綁到你指定的名字，愛放哪就放哪 | 不斷 |
| `as?->` | 同 `as->` | 中途 `nil` 就整串回 `nil` |
| `juxt` | 不是管道：把同一組參數餵給好幾個函式 | — |

```janet
(-> 5 (- 1) (* 2))                # => 8
(->> 5 (- 1) (* 2))               # => -8
(-?> nil (+ 1))                   # => nil
(-?>> @{:a 1} (get :b) (+ 1))     # => nil
(as-> 5 x (- x 1) (* x 2))        # => 8
((juxt + *) 2 3)                  # => (5 6)
```

⚠ `juxt` 是巨集，`juxt*` 是**函式**版（吃一串函式當參數）；兩個回傳的都是 tuple。
教學見 [01c](../docs/01c-解構與執行緒巨集.md)。

## 數值就地更新（8 個）

全部展開成一個 `set`，所以**對象一定要是 `var`**：

```janet
(do (var n 5) (++ n) n)        # => 6
(do (var n 5) (-- n) n)        # => 4
(do (var n 5) (+= n 3) n)      # => 8
(do (var n 5) (%= n 3) n)      # => 2
(do (var n 5) (/= n 2) n)      # => 2.5
(do (var b true) (toggle b) b) # => false
```

⚠ `/=` 是**真除法**不是整數除法（`5 / 2` 得 `2.5`），要地板除用 `div`（見
[數字型別與位元](數字型別與位元.md)）。`toggle` 就是 `(set x (not x))`，
所以它把任何真值換成 `false`、任何假值換成 `true`。

## 其他（5 個）

| 名 | 形狀 | 說明 |
|----|------|------|
| `comment` | `(comment & body)` | 整段不求值，回 `nil`；用來放暫時停用的程式碼 |
| `delay` | `(delay & body)` | 回一個函式，**第一次呼叫才算、之後回快取** |
| `short-fn` | `(short-fn body)`，讀法 `\|(…)` | `$`／`$0`／`$1`… 當參數 |
| `doc` | `(doc [name])` | 印說明；不給名字就印整個 env 的清單 |
| `tracev` | `(tracev x)` | 把 `x` 的原文和值印到 **stderr**，再原封不動回傳 `x` |

```janet
(do (def d (delay (+ 1 2))) [(d) (d)])   # => (3 3)
(|(+ $0 $1) 1 2)                         # => 3
(| (+ $ 1) 2)                            # => 3
```

⚠ `tracev` 走 stderr，所以把 stdout 導到檔案時它**還是會出現在畫面上**；
它回傳原值，可以直接塞進運算式中間不影響結果。
