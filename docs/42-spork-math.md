# 42 · spork/math：統計、數論、線性代數

內建的 `math/` 只有三角函數、開根號那些（見 [21 數字與位元](21-數字與位元.md)）。
`spork/math` 是完全不同的一包：**敘述統計、假設檢定、線性代數、數論**，
八十幾個函式。這篇講「什麼時候伸手拿它」以及四個猜不到的地方。

```janet
(import spork/math :as m)
```

## ⚠ 一、**沒有 `mean`**

第一個會撞到的就是它：

```janet
m/mean    # => compile error: unknown symbol m/mean
```

有 `geometric-mean`、`harmonic-mean`、`add-to-mean`，就是**沒有算術平均**。
自己算：`(/ (sum xs) (length xs))`。

這不只是少一個函式——`z-score` 的簽名是 **`(z-score x m d)`**，
`m` 和 `d` 都要你自己餵：

```janet
(def xs [2 4 4 4 5 5 7 9])
(def 平均 (/ (sum xs) (length xs)))            # => 5
(m/z-score 5 平均 (m/standard-deviation xs))   # => 0
```

⚠ 而且這是 **compile error 不是執行期錯誤**——`try` 攔不到（見 [33](33-函式參數與閉包.md)）。
好處是打錯名字馬上知道。

## ⚠ 二、函式名有拼字錯誤

```janet
(m/binominal-coeficient 5 2)   # => 10
```

正確拼法是 *binomial coefficient*，但這個函式叫 **`binominal-coeficient`**
——多一個 `n`、少一個 `f`。同系列的 `binominal-distribution` 也一樣。
**照正確拼法你永遠找不到它。**

> 教訓：spork 的模組**先列一次再用**，不要憑英文直覺猜名字：
> ```janet
> (import spork/math :as m)
> (filter |(string/has-prefix? "m/" (string $)) (keys (curenv)))
> ```
> 這招對任何 spork 模組都管用（原理見 [12 env](12-env-環境與動態變數.md)）。

## ⚠ 三、有些函式只吃**可變** array

```janet
(m/permutations [1 2 3])    # ✘ error: expected array, table or buffer, got <tuple>
(m/permutations @[1 2 3])   # ✓ => @[@[1 2 3] @[2 1 3] @[3 1 2] …]
```

因為它內部用 `swap` 原地交換。錯誤訊息講的是型別，**不會提示你「加個 `@` 就好」**。
遇到 `expected array, table or buffer` 先看看是不是餵了 tuple。

## ⚠ 四、`primes` 是**無界生成器**，不是清單

```janet
(m/primes)              # => <fiber>   ⚠ 不是陣列
(take 10 (m/primes))    # => @[2 3 5 7 11 13 17 19 23 29]
```

它是個 fiber（[09](09-fiber.md)），要多少取多少。
[25 序列工具](25-序列工具.md) 說「Janet 沒有惰性序列」——**這就是那條規則的例外**：
用 fiber 手動做出來的惰性。直接 `(m/primes)` 丟給 `length` 或 `pp` 會跑不完。

## 敘述統計

拿 `[2 4 4 4 5 5 7 9]` 實測：

| 函式 | 結果 | 說明 |
|------|------|------|
| `median` | `4.5` | 中位數 |
| `mode` | `4` | 眾數 |
| `variance` | `4` | **母體**變異數（除以 n）|
| `sample-variance` | `4.571…` | **樣本**變異數（除以 n−1）|
| `standard-deviation` | `2` | 母體標準差 |
| `sample-standard-deviation` | `2.138…` | 樣本標準差 |
| `geometric-mean` | `4.603…` | 幾何平均 |
| `harmonic-mean` | `4.201…` | 調和平均 |
| `root-mean-square` | `5.385…` | 均方根 |
| `interquartile-range` | `2` | 四分位距 |
| `quantile` | `(m/quantile xs 0.5)` → `4.5` | 分位數 |
| `extent` | `[2 9]` | 最小與最大 |

⚠ **`variance` 是母體版、`sample-variance` 是樣本版**（分母 n vs n−1）。
名字沒有前綴的那個是母體版——跟多數統計軟體的預設**相反**（R 的 `var` 是樣本版）。
拿實驗資料算統計量時幾乎都該用 `sample-` 那組。

還有 `sum-compensated`（Kahan 補償求和，累加大量浮點數時比 `sum` 準）。

## 檢定與迴歸

```janet
(m/sample-correlation [1 2 3 4 5] [2 4 5 4 5])   # => 0.7745…
(m/linear-regression [[1 2] [2 4] [3 5]])        # => {:m 1.5 :b 0.666…}
(m/t-test [1 2 3 4 5] 3)                          # => 0
(m/approx-eq 0.1 0.1000000001)                    # => true
```

`linear-regression` 回 `{:m 斜率 :b 截距}`；配 `linear-regression-line` 拿到可以代入 x 的函式。
`approx-eq` 就是 [21](21-數字與位元.md) 說的「浮點數比差值」，不用自己寫。

另有 `t-test-2`（雙樣本）、`permutation-test`、以及常態／卡方／二項／Poisson 的分布表。

## 線性代數

矩陣就是**陣列的陣列**，沒有專門型別：

```janet
(def A [[1 2] [3 4]])
(m/det A)                 # => -2
(m/trans A)               # => @[@[1 3] @[2 4]]
(m/matmul A (m/ident 2))  # => @[@[1 2] @[3 4]]
(m/dot [1 2] [3 4])       # => 11
(m/size A)                # => (2 2)     [列 行]
```

⚠ **輸入吃 tuple，輸出一律是 `@[@[…]]`（可變 array）**。要不可變的結果自己
`freeze`（見 [35](35-拷貝與凍結.md)）。

還有 `qr`／`svd`／`minor`／`invmod`；真的要做重量級數值運算，
考慮 `spork/tarray`（typed array）或直接走 FFI 接 BLAS（[10](10-c-互通.md)）。

## 數論

```janet
(m/prime? 97)          # => true
(m/next-prime 100)     # => 101
(m/factorial 10)       # => 3628800
(m/factor 84)          # => @[2 2 3 7]      質因數分解
(m/powmod 2 10 1000)   # => 24              (2^10) mod 1000，不會溢位
(m/invmod 3 11)        # => 4               模反元素
```

⚠ 這些吃的是一般 Janet 數字，所以**受 2^53 精度限制**（[21](21-數字與位元.md)）。
要大數請走 `int/s64`／`int/u64`。

## 可跑範例

`janet examples/spork-math.janet`——上面每個表都在你的機器上重算一次，
四個 ⚠ 也都做成看得見的實驗（含用 `compile` 示範 `m/mean` 不存在）。

下一步：回 [主題與 spork 索引](主題與-spork-索引.md)。
