# spork/randgen ・ 隨機抽樣

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/randgen`（14 個）是隨機抽樣的工具箱：均勻分布、高斯（常態）分布、依權重抽樣、
CDF（**累積分布函式**——把一組權重換算成「累計到目前為止的機率」，抽樣時用二分搜尋就能
很快找到落在哪一段）。日期與排程收在 [date-cron-日期與排程.md](date-cron-日期與排程.md)。

## 函式表

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `*rng*` | 動態變數 keyword | 目前用的隨機數產生器；`setdyn` 換掉可讓下面所有函式改用自訂 RNG |
| `set-seed` | `(set-seed seed)` | 設定全域隨機種子（固定種子＝可重現） |
| `rand-uniform` | `(rand-uniform)` | `[0,1)` 均勻分布亂數 |
| `rand-int` | `(rand-int start end)` | `[start,end)` 範圍的均勻整數 |
| `rand-gaussian` | `(rand-gaussian &opt m sd)` | 常態（高斯）分布亂數，預設平均 0、標準差 1 |
| `rand-value` | `(rand-value xs)` | 從索引型結構隨機取一個值 |
| `rand-index` | `(rand-index xs)` | 隨機取一個合法索引（不是值本身） |
| `rand-path` | `(rand-path & paths)` | 巨集：隨機挑一段程式碼執行（均勻機率） |
| `weights-to-cdf` | `(weights-to-cdf weights)` | 把一組權重轉成累積分布函式（CDF），給下面 `rand-cdf` 用比較有效率 |
| `rand-cdf` | `(rand-cdf cdf)` | 依累積分布抽一個索引 |
| `rand-cdf-path` | `(rand-cdf-path cdf & paths)` | 巨集：依 CDF 隨機挑一段程式碼執行 |
| `rand-weights` | `(rand-weights weights)` | 依一組權重抽一個索引（內部會自己轉成 CDF） |
| `rand-weights-path` | `(rand-weights-path weights & paths)` | 巨集：依權重隨機挑一段程式碼執行 |
| `sample-n` | `(sample-n f n)` | 呼叫抽樣函式 `f` 共 `n` 次，收集結果成陣列 |

## 實測範例

```janet
(import spork/randgen)

(randgen/set-seed 42)
(randgen/rand-uniform)   # => 0.900358161924284
(randgen/set-seed 42)
(randgen/rand-uniform)   # => 0.900358161924284   同種子 -> 同結果，可重現

(randgen/set-seed 1)
(randgen/sample-n |(randgen/rand-int 0 6) 10)
# => @[1 5 1 3 5 1 3 3 0 2]   抽 10 次 [0,6) 範圍的整數

(randgen/rand-gaussian)          # => 0.318756480188982     標準常態（平均 0 標準差 1）
(randgen/rand-gaussian 100 15)   # => 115.104538039321       平均 100 標準差 15

(randgen/rand-value ["a" "b" "c"])  # => "a"
(randgen/rand-index ["a" "b" "c"])  # => 2
(randgen/rand-path 1 2 3)           # => 隨機挑一段（例如印出 1）
```

依權重／CDF 抽樣：

```janet
(def cdf (randgen/weights-to-cdf [1 1 2]))
cdf  # => @[0.25 0.5 1]     權重 [1 1 2] 轉成累積機率：0.25／0.5／1.0

(randgen/set-seed 1)
(randgen/sample-n |(randgen/rand-cdf cdf) 10)
# => @[0 2 1 2 2 0 2 2 0 1]   索引 2（權重最大）出現頻率明顯較高

(randgen/set-seed 1)
(randgen/sample-n |(randgen/rand-weights [1 1 2]) 10)
# => @[0 2 1 2 2 0 2 2 0 1]   結果跟上面 rand-cdf 一致，rand-weights 只是內部多做一次轉換

(randgen/rand-weights-path [1 1 2] :a :b :c)          # => :a
(randgen/rand-cdf-path (randgen/weights-to-cdf [1 1 2]) :a :b :c)  # => :a
```

⚠ 想要「這一串抽樣不要受全域種子影響、也不影響全域狀態」，用 `*rng*` 動態變數換掉整個 RNG
（跟 `set-seed` 是兩條獨立的路，互不影響）：

```janet
(setdyn randgen/*rng* (math/rng 5))
(randgen/rand-uniform)   # => 0.382155406432575
(setdyn randgen/*rng* (math/rng 5))
(randgen/rand-uniform)   # => 0.382155406432575   同樣可重現
```
