# spork/math ・ 統計與機率（二）迴歸／檢定／機率分布

[← spork 索引](README.md)｜[← reference 索引](../README.md)

接續 [math-統計與機率.md](math-統計與機率.md)（敘述統計）：這裡收線性迴歸、假設檢定、離散分布產生器、常態分布查表。

## 線性迴歸

| 函式 | 簽名 | 說明 |
|---|---|---|
| `linear-regression` | `(linear-regression coords)` | `coords` 是 `[[x y] ...]` 座標點，回傳 `{:m 斜率 :b 截距}`（最小平方法） |
| `linear-regression-line` | `(linear-regression-line {:b b :m m})` | 把上面的 struct 變成函式 `(fn [x] (+ b (* m x)))`，可直接呼叫算預測值 |

## 假設檢定

| 函式 | 簽名 | 說明 |
|---|---|---|
| `t-test` | `(t-test xs expv)` | 單樣本 t 檢定：`xs` 的平均值跟已知值 `expv` 有沒有顯著差異，回傳 t 統計量 |
| `t-test-2` | `(t-test-2 xs ys &opt d)` | 兩獨立樣本 t 檢定（假設變異數相同，pooled variance），`d` 是期望差值，預設 0 |
| `permutation-test` | `(permutation-test xs ys &opt a k)` | 排列檢定：不假設分布形狀，靠反覆隨機重排 `xs`／`ys` 合併後拆兩半來估計「兩組平均差異有多顯著」。`a` 是對立假設 `:two-side`（預設）／`:greater`／`:lesser`，`k` 是重排次數（預設 1e4），回傳 p 值 |

## 機率相關工具

| 函式 | 簽名 | 說明 |
|---|---|---|
| `check-probability` | `(check-probability p)` | assert `p` 落在 `[0,1]`，是其他機率函式的內部檢查，通常不用直接呼叫 |
| `cumulative-std-normal-probability` | `(cumulative-std-normal-probability z)` | 標準常態分布的累積機率 `P(Z<=z)`，查 `standard-normal-table` 實作 |
| `standard-normal-table` | tuple | 預先算好的標準常態分布查表，`z` 從 0 到 3.09、間隔 0.01，共 310 筆 |
| `chi-squared-distribution-table` | struct | 卡方分布查表，外層 key 是自由度，內層 key 是顯著水準（如 `0.05`），值是臨界值 |

## 離散分布產生器

| 函式 | 簽名 | 說明 |
|---|---|---|
| `bernoulli-distribution` | `(bernoulli-distribution p)` | 白努利分布（丟一次硬幣），回傳 `[失敗機率 成功機率]` |
| `binominal-distribution` | `(binominal-distribution t p)` | 二項分布：`t` 次獨立試驗、每次成功機率 `p`，回傳「成功 0 次、1 次、2 次…」機率的 tuple（累積到約 `1-epsilon` 就停） |
| `poisson-distribution` | `(poisson-distribution lambda)` | 卜瓦松分布：平均發生率 `lambda`，回傳「發生 0 次、1 次、2 次…」機率的 tuple |

## 實測範例

```
(import spork/math)
(math/linear-regression [[1 2] [2 4] [3 6]])          # => {:b 0 :m 2}   y = 2x
(def f (math/linear-regression-line {:m 2 :b 0}))
(f 5)                                                  # => 10
(math/t-test [5 6 7 8 9] 5)                            # => 3.16227766016838
(math/t-test-2 [5 6 7 8] [1 2 3 4])                    # => 4.38178046004133
(math/permutation-test [1 2 3 4 5] [10 20 30 40 50])   # => 0.0071   (兩組差異極顯著，p 很小)
(math/cumulative-std-normal-probability 0)             # => 0.5
(math/cumulative-std-normal-probability 1.96)          # => 0.975
(math/cumulative-std-normal-probability -1.96)         # => 0.025
(get-in math/chi-squared-distribution-table [1 0.05])  # => 3.84
(math/bernoulli-distribution 0.3)                      # => (0.7 0.3)
(math/binominal-distribution 5 0.5)                    # => [0.03125 0.15625 0.3125 0.3125 0.15625 0.03125]
(math/poisson-distribution 2)                          # => [0.135335283236613 0.270670566473225 0.270670566473225 ...]  共 10 項到約 1-epsilon 停
```

⚠ `permutation-test` 內部會直接**合併並重排** `xs`／`ys` 的複本（用 `shuffle-in-place`，靠全域 `math/random` 當種子來源），呼叫前後 `xs`／`ys` 本身不會被動到，但每次執行結果會因隨機重排而略有差異（除非你自己控制隨機種子）；上面 `0.0071` 這個數字每次重跑可能有些微差異。

⚠ `binominal-distribution` 與 `poisson-distribution` 都是「算到累積機率超過 `1 - epsilon`（`epsilon` 是線代那份提到的 `0.0001`）就停」，回傳的 tuple **長度不固定**，且不保證涵蓋分布的全部支撐——尾巴機率極小的部分會被直接捨棄。
