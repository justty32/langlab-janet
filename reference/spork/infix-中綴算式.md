# spork/infix ・ 中綴算式

[← spork 索引](README.md)｜[← reference 索引](../README.md)

整個模組只有一個公開綁定 `$$`，但它是一套小語言：把 `a + b * c` 這種**中綴**寫法在編譯期翻成
Janet 正常的前綴呼叫。移植數學公式、或算式裡運算子多到括號數不清的時候用它，其餘場合照常寫前綴。
[資料格式與驗證.md](資料格式與驗證.md) 已經帶過三行，這份把運算子、優先序、以及優先序表裡的
兩個陷阱補齊。

`$$` 是**巨集**，翻譯發生在編譯期，跑起來沒有額外成本——`(macex1 '($$ a + b ** 2))` 會看到
`(+ a (<cfunction math/pow> b 2))`，函式物件是直接嵌進去的，不是符號。

## 運算子全表（數字越大綁越緊）

| 優先序 | 運算子 | 翻成 |
|---|---|---|
| 40 | `!` `not` `bnot` `++` `--`（前綴一元） | `not` `not` `bnot` `++` `--` |
| 30 | `**`（**右結合**） | `math/pow` |
| 20 | `*` `/` `%` | 同名 |
| 10 | `+` `-`（`-` 也當一元負號用） | 同名 |
| 9 | `<<` `>>` `>>>` | `blshift` `brshift` `brushift` |
| 8 | `=` `!=` `not=` `<` `<=` `>` `>=` | `=` `not=` `not=` `<` `<=` `>` `>=` |
| 7 | `&` | `band` |
| 6 | `^` | `bxor` |
| 5 | `bor` `band` | 同名 |
| 4 | `and` | 同名 |
| 3 | `or` | 同名 |

沒有後綴一元運算子。方括號 `y[i]` 是索引（翻成 `in`），圓括號是分組，
分組結果若仍是一個 tuple 就當**函式呼叫**的引數列。

## 實測

```janet
(import spork/infix)

(infix/$$ 1 + 2 * 3)               # => 7
(infix/$$ 2 ** 3 ** 2)             # => 512    右結合，等於 2^(3^2)
(infix/$$ 7 / 2)                   # => 3.5
(infix/$$ 7 % 3)                   # => 1

(infix/$$ 1 << 4)                  # => 16
(infix/$$ 255 >> 4)                # => 15
(infix/$$ 0xFF >>> 4)              # => 15
(infix/$$ 6 & 3)                   # => 2
(infix/$$ 6 ^ 3)                   # => 5
(infix/$$ 6 bor 3)                 # => 7
(infix/$$ 6 band 3)                # => 2
(infix/$$ bnot 0)                  # => -1

(infix/$$ 1 != 2)                  # => true
(infix/$$ 1 not= 2)                # => true
(infix/$$ 3 > 2 and 2 > 1)         # => true
(infix/$$ 1 > 2 or 3 > 2)          # => true
(infix/$$ not (1 = 2))             # => true
```

索引、函式呼叫、跳出中綴語法：

```janet
(import spork/infix)
(def y [10 20 30])
(def m @{:a @[1 2 3]})

(infix/$$ y[0] + y[2])             # => 40
(infix/$$ m[:a][1])                # => 2
(infix/$$ math/sqrt (2 * 8))       # => 4
(infix/$$ 2 * math/pi)             # => 6.2831853071795862
(infix/$$ ,(+ 1 2) * 3)            # => 9      逗號跳回一般 Janet
(infix/$$ '(1 2 3))                # => (1 2 3)   單引號整串原樣帶過
```

## ⚠ 一元負號跟其他一元運算子不同級

優先序表裡 `-` 只有一筆，值是 **10**（二元減法那一筆），一元負號沿用同一個值；
`!` `not` `bnot` `++` `--` 則是 40。結果是**負號綁得比乘除鬆**：

```janet
(import spork/infix)
(macex1 '(infix/$$ - a * b))       # 展開成 (- (* a b))，不是 ((- a) * b)
(macex1 '(infix/$$ bnot a + b))    # 展開成 (+ (bnot a) b)，bnot 只吃 a
(infix/$$ - 3 ** 2)                # => -9
(infix/$$ - 3 * 2)                 # => -6
```

數值上 `-(a*b)` 跟 `(-a)*b` 一樣，所以多數時候不會出事；但 `- a / b` 這類寫法心裡要清楚
它是 `-(a/b)`。要指定就自己加括號：`(infix/$$ (- a) * b)`。

## ⚠ 比較運算子會串起來，而且不報錯

`a < b < c` 在數學課本上是「b 夾在中間」，這裡不是——它照左結合翻成 `(< (< a b) c)`，
先算出一個 boolean 再拿去跟 `c` 比：

```janet
(import spork/infix)
(infix/$$ 1 < 2 < 3)               # => false
```

`(< true 3)` 在 Janet 裡是合法的（跨型別比較有總序，boolean 排在 number 前面），
所以整條式子**安靜地給你錯答案**。要夾擊就寫 `(infix/$$ 1 < 2 and 2 < 3)`。

## ⚠ 函式呼叫的引數括號不能只包一個值

`(math/sqrt (2 * 8))` 能用，是因為 `(2 * 8)` 翻完還是一個 tuple `(* 2 8)`，`$$` 看到
tuple 才當成呼叫。引數只有單一個數字或符號時，那層括號在翻譯中被抹掉，`$$` 就找不到
運算子：

```janet
(import spork/infix)
(protect (eval '(infix/$$ math/sqrt (16.0))))   # => (false "(macro) expected binary operator, got 16")
(protect (eval '(infix/$$ math/sqrt (x))))      # => (false "(macro) expected binary operator, got x")
```

繞法有兩種：把引數寫成一個真算式（`(16.0 + 0.0)`），或整個呼叫用逗號跳出中綴
（`(infix/$$ 1 + ,(math/sqrt 16))`）。

其他錯誤訊息：`(infix/$$)` 回 `expected non-empty expression, got ()`；
`(infix/$$ 1 2)` 回 `expected binary operator, got 2`。缺右運算元的 `(infix/$$ 1 +)`
不會在展開期擋下來，而是展開成 `(+ 1)` 之後在執行期喊 `could not find method :+`。
