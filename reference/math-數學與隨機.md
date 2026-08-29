# math ・ 數學與隨機

[← reference 索引](README.md)

這份窮舉 Janet 1.41.2 `root-env` 裡實際存在的全部 53 個 `math/*`（用 `grep '^math/' rootenv.txt` 核過數量），照類別分節、每個都給實測值。想先掌握「怎麼用隨機數」這種循序漸進的講法，看教學 docs/26-隨機數.md；這裡是查表用的。

## 常數（9 個）

| 名字 | 值（實測） | 說明 |
|---|---|---|
| `math/pi` | `3.14159265358979` | 圓周率 π |
| `math/e` | `2.71828182845905` | 自然對數的底 e |
| `math/inf` | `inf` | 正無窮 |
| `math/-inf` | `-inf` | 負無窮 |
| `math/nan` | `nan` | 不是一個數字（IEEE-754 NaN）。任何比較都是 false，連 `(= math/nan math/nan)` 也是 false，要判斷用 `math/nan?`（不在本表，那是 boot.janet 定義的一般函式，不是 `math/*` 底層） |
| `math/int-max` | `9007199254740992`（2^53） | double 能精確表示的最大連續整數 |
| `math/int-min` | `-9007199254740992` | 同上，負的 |
| `math/int32-max` | `2147483647` | 32 位元有號整數上限 |
| `math/int32-min` | `-2147483648` | 32 位元有號整數下限 |

## 取整（5 個）：floor／ceil／round／trunc／abs

```
(math/floor 3.7)   # => 3        (math/floor -3.7)  # => -4
(math/ceil 3.2)    # => 4        (math/ceil -3.2)   # => -3
(math/round 3.5)   # => 4        (math/round 2.5)   # => 3
(math/round -2.5)  # => -3
(math/trunc 3.9)   # => 3        (math/trunc -3.9)  # => -3
(math/abs -5)      # => 5        (math/abs -5.5)    # => 5.5
```

⚠ `math/round` 是「四捨五入、遠離零」（round half away from zero），**不是**銀行家捨入：`2.5` 進到 `3`、`-2.5` 進到 `-3`，兩邊都往外捨，不是「捨入到最近的偶數」。

## 冪、根、對數（10 個）

`pow` `exp` `exp2` `expm1` `log` `log10` `log2` `log1p` `sqrt` `cbrt`

```
(math/pow 2 10)      # => 1024                    a^x，(math/pow a x)
(math/exp 1)         # => 2.71828182845905        e^x
(math/exp2 10)       # => 1024                    2^x
(math/expm1 0.0001)  # => 0.000100005000166671    e^x - 1，x 很小時比 (- (exp x) 1) 精確
(math/log math/e)    # => 1                       自然對數 ln
(math/log10 1000)    # => 3
(math/log2 8)        # => 3
(math/log1p 0.0001)  # => 9.99950003333083e-05    ln(1+x)，x 很小時比 (log (+ 1 x)) 精確
(math/sqrt 2)         # => 1.4142135623731
(math/cbrt 27)        # => 3                      立方根
```

## 三角與雙曲函式（13 個）

`sin` `cos` `tan` `asin` `acos` `atan` `atan2` `sinh` `cosh` `tanh` `asinh` `acosh` `atanh`

```
(math/sin 0) (math/cos 0) (math/tan 0)       # => 0  1  0
(math/asin 1)     # => 1.5707963267949   (= pi/2)
(math/acos 1)     # => 0
(math/atan 1)     # => 0.785398163397448  (= pi/4)
(math/atan2 1 1)  # => 0.785398163397448  atan(y/x)，會自己判斷象限，兩參數是 (y x)
(math/sinh 0) (math/cosh 0) (math/tanh 0)    # => 0  1  0
(math/asinh 1)     # => 0.881373587019543
(math/acosh 1)     # => 0
(math/atanh 0.5)   # => 0.549306144334055
```

## 特殊函式（4 個）

| 名字 | 實測 | 白話 |
|---|---|---|
| `math/erf` | `(math/erf 1)` => `0.842700792949715` | 誤差函式。算常態分布「落在某範圍的機率」時會用到，其他場合幾乎碰不到。 |
| `math/erfc` | `(math/erfc 1)` => `0.157299207050285` | = 1 − erf(x)。幾乎用不到，列在這裡是為了完整。 |
| `math/gamma` | `(math/gamma 5)` => `24` | Gamma 函式。正整數時 `gamma(n) = (n-1)!`，統計、排列組合會遇到。 |
| `math/log-gamma` | `(math/log-gamma 5)` => `3.17805383034795` | = ln(gamma(x))。x 大時 gamma(x) 本身會先溢位，改算它的 log 比較安全。 |

## 整數／浮點工具（6 個）

| 名字 | 簽名 | 實測 | 白話 |
|---|---|---|---|
| `math/gcd` | `(math/gcd x y)` | `(math/gcd 12 18)` => `6` | 最大公因數 |
| `math/lcm` | `(math/lcm x y)` | `(math/lcm 4 6)` => `12` | 最小公倍數 |
| `math/hypot` | `(math/hypot a b)` | `(math/hypot 3 4)` => `5` | `sqrt(a²+b²)`，比自己寫更不容易中途溢位 |
| `math/next` | `(math/next x y)` | `(math/next 1.0 2.0)` => 印出來是 `1`，用 `(string/format "%.20f" ...)` 才看得出是 `1.00000000000000022204` | 從 x 往 y 方向數過去、下一個「機器能表示」的浮點數，debug 浮點誤差時會用 |
| `math/frexp` | `(math/frexp x)` | `(math/frexp 8.0)` => `(0.5 4)`；`(math/frexp 100.0)` => `(0.78125 7)` | 把 x 拆成 `(尾數 指數)`，滿足 `x = 尾數 * 2^指數`，尾數落在 `[0.5, 1)`。尾數＝浮點數裡「有效數字」的部分，指數＝縮放用的 2 的次方 |
| `math/ldexp` | `(math/ldexp m e)` | `(math/ldexp 0.5 4)` => `8` | frexp 的反操作：`m * 2^e` |

## 隨機數（6 個）

對應教學：docs/26-隨機數.md（這裡只列全部可用的東西）。

| 名字 | 簽名 |
|---|---|
| `math/random` | `(math/random)` |
| `math/seedrandom` | `(math/seedrandom seed)` |
| `math/rng` | `(math/rng &opt seed)` |
| `math/rng-int` | `(math/rng-int rng &opt max)` |
| `math/rng-uniform` | `(math/rng-uniform rng)` |
| `math/rng-buffer` | `(math/rng-buffer rng n &opt buf)` |

實測：

```
(math/random)                        # => 0.487181187691715   [0,1) 均勻分布浮點數，用「全域」隱藏狀態
(math/seedrandom 42) (math/random)   # => 0.900358161924284
(math/seedrandom 42) (math/random)   # => 0.900358161924284   種子固定 -> 結果可重現
```

`math/random` / `math/seedrandom` 動的是全域內建的 PRNG（偽隨機數產生器：靠一個公式一直算出「看起來隨機」的數列，種子固定整串就重現）。要「自己拿一份獨立、不跟全域互相干擾」的隨機數狀態，用 `math/rng`：

```
(def r (math/rng 1))
(math/rng-int r)       # => 1933504430   不給 max 時，回傳一個 0 ~ 約 21 億的正整數（32-bit 範圍內）
(math/rng-int r 6)     # => 連續呼叫 10 次得到 3 2 1 1 3 4 1 3 5 3，都落在 [0,6) 之間
(math/rng-uniform r)   # => 0.387218556853928   [0,1) 均勻分布浮點數
(math/rng-buffer r 5)  # => 長度 5 的 buffer，塞滿隨機 byte（印出來是亂碼，因為是原始位元組不是文字）
```

`math/rng-buffer` 可以帶第三個參數 `buf`，把結果寫進既有 buffer（省一次配置）而不是新建一個。
