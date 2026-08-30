# spork/math ・ 統計與機率（一）敘述統計

[← spork 索引](README.md)｜[← reference 索引](../README.md)

本檔收 `spork/math` 裡描述一組數字「長什麼樣子」的敘述統計函式：極值、平均數家族、離散程度、分位數。檢定（t-test）與機率分布在 [math-統計與機率b-檢定與機率分布.md](math-統計與機率b-檢定與機率分布.md)；矩陣/向量在 [math-線性代數.md](math-線性代數.md)（那份開頭有 spork/math vs 內建 math/* 的說明）。全部以 `xs = [2 4 4 4 5 5 7 9]` 實測。

## 極值與加總

| 函式 | 簽名 | 說明 |
|---|---|---|
| `extent` | `(extent xs)` | `[最小值 最大值]` |
| `sum-compensated` | `(sum-compensated xs)` | 用 Kahan-Babushka 演算法加總，減少浮點誤差累積 |
| `sum-nth-power-deviations` | `(sum-nth-power-deviations xs n)` | `Σ(x-mean)^n`，是 variance／skewness 的共用底層 |

## 平均數家族

| 函式 | 簽名 | 說明 |
|---|---|---|
| `geometric-mean` | `(geometric-mean xs)` | 幾何平均，`xs` 全部須為正數 |
| `harmonic-mean` | `(harmonic-mean xs)` | 調和平均，`xs` 全部須為正數 |
| `root-mean-square` | `(root-mean-square xs)` | 均方根 |
| `add-to-mean` | `(add-to-mean m n v)` | 已知 `n` 筆資料的平均是 `m`，新增一筆值 `v` 後的新平均（不用重掃全部資料） |

## 離散程度

| 函式 | 簽名 | 說明 |
|---|---|---|
| `variance` | `(variance xs)` | 母體變異數（除以 n） |
| `sample-variance` | `(sample-variance xs)` | 樣本變異數（除以 n-1，貝索校正） |
| `standard-deviation` | `(standard-deviation xs)` | `sqrt(variance)` |
| `sample-standard-deviation` | `(sample-standard-deviation xs)` | `sqrt(sample-variance)` |
| `median-absolute-deviation` | `(median-absolute-deviation xs)` | 每個值到中位數距離的中位數，比標準差更抗極端值 |
| `sample-skewness` | `(sample-skewness xs)` | 偏度：分布往左或往右歪的程度，正值代表右邊尾巴較長，`xs` 至少 3 筆 |
| `z-score` | `(z-score x m d)` | 標準分數 `(x-m)/d` |

## 相關與共變異

| 函式 | 簽名 | 說明 |
|---|---|---|
| `sample-covariance` | `(sample-covariance xs ys)` | 兩序列的樣本共變異數 |
| `sample-correlation` | `(sample-correlation xs ys)` | 皮爾森相關係數，範圍 `[-1,1]` |

## 中心與分位數

| 函式 | 簽名 | 說明 |
|---|---|---|
| `median` | `(median xs)` | 中位數（內部即 `(quantile xs 0.5)`） |
| `mode` | `(mode xs)` | 眾數 |
| `quantile` | `(quantile xs p)` | `xs`（**不必先排序**）在百分位 `p`（`0~1`）的值 |
| `quantile-sorted` | `(quantile-sorted xs p)` | 同上，但要求 `xs` **已排序**（省一次排序） |
| `quantile-rank` | `(quantile-rank xs p)` | 反查：數值 `p` 落在 `xs` 的百分位排名 |
| `quantile-rank-sorted` | `(quantile-rank-sorted xs v)` | 同上，`xs` 已排序 |
| `interquartile-range` | `(interquartile-range xs)` | Q3-Q1（`quantile 0.75` 減 `quantile 0.25`） |

## 實測範例

```
(import spork/math)
(def xs [2 4 4 4 5 5 7 9])
(math/extent xs)                    # => (2 9)
(math/sum-compensated xs)           # => 40
(math/variance xs)                  # => 4
(math/sample-variance xs)           # => 4.57142857142857
(math/standard-deviation xs)        # => 2
(math/sample-standard-deviation xs) # => 2.1380899352994
(math/median xs)                    # => 4.5
(math/median-absolute-deviation xs) # => 0.5
(math/geometric-mean [1 2 4 8])     # => 2.82842712474619
(math/harmonic-mean [1 2 4])        # => 1.71428571428571
(math/root-mean-square xs)          # => 5.3851648071345
(math/sample-skewness xs)           # => 0.8184875533568
(math/interquartile-range xs)       # => 2
(math/z-score 5 4.5 1.0)            # => 0.5
(math/add-to-mean 4.5 8 10)         # => 5.11111111111111   (4.5*8+10)/9
(math/sample-correlation [1 2 3 4 5] [2 4 5 4 5])  # => 0.774596669241483
(math/sample-covariance  [1 2 3 4 5] [2 4 5 4 5])  # => 1.5
(math/quantile xs 0.5)              # => 4.5
(math/quantile xs 0)                # => 2      (p=0 就是最小值)
(math/quantile xs 1)                # => 9      (p=1 就是最大值)
(math/quantile-rank xs 5)           # => 0.6875
(math/quantile-rank xs -1)          # => 0      p 定義域外會夾在 0
(math/quantile-rank xs 100)         # => 1      超出上界夾在 1
```

⚠ `quantile` 的 `p` 是 `[0,1]` 之間的比例（不是百分比 `0~100`），`(quantile xs 0.5)` 才是中位數；`quantile` 內部會先複製一份 `xs` 再用 `quickselect` 做部分排序，**不會 mutate 原陣列**，但複製只淺拷貝（見線代那份 `copy` 的警告），所以巢狀資料一樣要小心。

⚠ **`mode` 對多眾數（tie）的行為未定義**：內部靠 `(frequencies xs)` 再 `invert` 成「次數 → 值」的 table，多個值出現次數相同時，`invert` 只會留下**其中一個**（依 table 內部雜湊順序決定，不是「最先出現」也不是「最小值」），例如：

```
(math/mode [1 1 2 2 3])   # => 2   而不是常見習慣認為的「1」（先出現者優先）
```

若序列全空，`extent`／`variance`／`median` 等大多數函式會直接 assert 失敗噴錯（"xs cannot be empty" 之類），不會靜默回傳 `nil` 或 `0`。
