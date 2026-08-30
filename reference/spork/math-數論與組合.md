# spork/math ・ 數論與組合

[← spork 索引](README.md)｜[← reference 索引](../README.md)

本檔收 `spork/math` 裡跟整數性質（質數、階乘）與排列組合有關的函式。線性代數見 [math-線性代數.md](math-線性代數.md)（那份開頭有 spork/math vs 內建 math/* 的說明）；統計見 [math-統計與機率.md](math-統計與機率.md)。另外 `math/invmod`／`math/jacobi`／`math/mulmod`／`math/powmod`（模運算）其實是 `spork/cmath` 的函式，被 `spork/math` 內部 `import ... :export true` 進來，文檔見 [tarray-cmath.md](tarray-cmath.md)，本檔不重複列。

| 函式 | 簽名 | 說明 |
|---|---|---|
| `factorial` | `(factorial n)` | `n!`，`(factorial 0)` => `1` |
| `prime?` | `(prime? n)` | 質數判定，`n < 211` 查表、之外用 Jacobi 篩選 + Miller-Rabin，對 `n < 2^63` 是**確定性**（不是機率性測試） |
| `next-prime` | `(next-prime n)` | 嚴格大於 `n` 的下一個質數 |
| `primes` | `(primes)` | 回傳一個 **fiber**（無窮質數產生器），要 `resume` 一次拿一個 |
| `factor` | `(factor n)` | `n` 的質因數分解，回傳陣列（含重複，如 `12` => `[2 2 3]`） |
| `binominal-coeficient` | `(binominal-coeficient n k)` | 二項式係數 `C(n,k)`（注意函式名稱本身拼成 `coeficient`，少一個 f，不是筆誤，照抄） |
| `permutations` | `(permutations s &opt k)` | 產生 `s` 的排列，見下方警告——`k` **不是**輸出長度 |
| `quickselect` | `(quickselect arr k &opt left right)` | 原地重排 `arr`，讓 `[left,k]` 範圍內都是最小的那批值（第 k 大/小選擇演算法），是 `quantile` 的底層 |
| `shuffle-in-place` | `(shuffle-in-place xs &opt rng)` | 原地打亂 `xs`（Fisher-Yates），可傳自己的 `rng`（見內建 `math/rng`），預設用全域 `math/random` 派生 |

## 實測範例

```
(import spork/math)
(math/factorial 5)          # => 120
(math/prime? 17)            # => true
(math/prime? 1)             # => false
(math/next-prime 20)        # => 23
(math/factor 360)           # => @[2 2 2 3 3 5]
(math/factor 1)             # => @[]        1 沒有質因數，回傳空陣列
(math/binominal-coeficient 5 2)  # => 10
(def g (math/primes))
(seq [_ :range [0 5]] (resume g))   # => @[2 3 5 7 11]

(def a @[5 3 8 1 9 2])
(math/quickselect a 2)
a                            # => @[1 2 3 5 8 9]   k=2 位置排定第 3 小的值，兩側大略分堆

(math/seedrandom 1)
(math/shuffle-in-place @[1 2 3 4 5])   # => @[4 5 2 3 1]（種子固定則可重現）
```

⚠ **`permutations` 的 `k` 不是「輸出每筆的長度」**，輸出每筆永遠跟 `s` 一樣長；`k` 控制的是「前 `k` 個位置參與重排、總共產生幾筆」（大致是 `k!` 筆），後面 `(length s) - k` 個位置固定不動：

```
(math/permutations @[1 2 3])       # => 全部 6 筆，每筆長度都是 3
(math/permutations @[1 2 3] 2)     # => 只有 2 筆：@[@[1 2 3] @[2 1 3]]，每筆長度還是 3、第 3 個位置沒被排列到
(math/permutations @[1 2 3] 1)     # => 只有 1 筆（原樣）：@[@[1 2 3]]
```

⚠ `factor` 對大數靠 Pollard's rho 演算法分解，若 `n` 本身就是很大的質數（例如上百位數），實務上可能跑得慢；一般大小（int64 範圍內）沒問題。
