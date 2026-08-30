# spork/tarray ・ spork/cmath

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/tarray` 是 typed array（型別化陣列）：白話講，就是「一塊固定大小、固定型別（像 C 的 `int8_t`／`double` 那樣)的原始記憶體」，比一般 Janet array 省記憶體、存取也更快，常見用途是跟 C FFI／`spork/cc` 交換二進位資料。`spork/cmath` 是模運算數論的原生函式（模逆元／Jacobi 符號等），跟一般 `math/*` 完全無關；但透過 `spork/math.janet` 的無前綴 re-export，這 4 個函式也能用 `math/xxx` 呼叫，本檔一併說明這層關係。

## spork/tarray（7 個）

型別關鍵字（`type` 參數，共 10 種，來自原始碼 `ta_type_names`）：`:uint8` `:int8` `:uint16` `:int16` `:uint32` `:int32` `:uint64` `:int64` `:float32` `:float64`。

| 函式 | 簽名 | 說明 |
|---|---|---|
| `new` | `(tarray/new type size &opt stride offset tarray|buffer)` | 建一個 typed array「view」；不給最後一個參數就自動配一塊新的底層 buffer |
| `buffer` | `(tarray/buffer array|size)` | 吃 view 就回傳它底下的 buffer；吃數字（size）就新建一塊該大小的 buffer |
| `length` | `(tarray/length array|buffer)` | view 回「元素個數」，buffer 回「位元組數」 |
| `properties` | `(tarray/properties array)` | 回傳一個 struct，view 有 `:size :byte-offset :stride :type :type-size :buffer`；buffer 只有 `:size :big-endian` |
| `slice` | `(tarray/slice tarr &opt start end)` | 取 `[start end)` 區間（半開、可負索引），回傳一個**普通 Janet array**（不是 typed array） |
| `copy-bytes` | `(tarray/copy-bytes src sindex dst dindex &opt count)` | 把 src 從 sindex 起的 count 個元素複製到 dst 的 dindex 位置（`memmove` 語意，可重疊） |
| `swap-bytes` | `(tarray/swap-bytes src sindex dst dindex &opt count)` | 同上但雙向互換，兩邊值對調 |

### 實測範例

```
$ janet -e '(import spork/tarray)
  (def t (tarray/new :int8 5))
  (pp t)
  (pp (tarray/properties t))'
<ta/view 0x...>
{:buffer <ta/buffer 0x...> :byte-offset 0 :size 5 :stride 1 :type :int8 :type-size 1}
```

`tarray/buffer` 兩種吃法都測過：吃 view 拿到它的底層 buffer，吃數字直接新建：
```
(tarray/buffer t)   # => <ta/buffer 0x...>   (t 底下那塊)
(tarray/buffer 10)  # => <ta/buffer 0x...>   (全新 10 bytes)
```

寫入用 `put`、讀取可直接用 `get` 或索引語法，`slice` 拿出來是一般 array：
```
(for i 0 5 (put t i (* i 10)))
(tarray/slice t)      # => @[0 10 20 30 40]
(tarray/slice t 1 3)  # => @[10 20]
(tarray/slice t -3)   # => @[30 40]          負索引：從尾端算
```

⚠ int8 只有 8 bit，超出範圍會照 C 的整數溢位規則纏繞（wrap），不會報錯：
```
(def t2 (tarray/new :int8 5))
(for i 0 5 (put t2 i (* 100 (+ 1 i))))
(tarray/slice t2)    # => @[100 -56 44 -112 -12]   200/300/400/500 都繞回負數了
```

`swap-bytes` 真的會雙向互換（各拿 2 個元素對調）：
```
(tarray/swap-bytes t 0 t2 0 2)
(tarray/slice t)   # => @[100 -56 20 30 40]
(tarray/slice t2)  # => @[0 10 44 -112 -12]
```

⚠ `:uint64`／`:int64` 存取回來的不是普通 number，是 `core/u64`／`core/s64` 這種 64 位元整數 abstract type（一般 Janet number 是 double，撐不住完整 64 位精度）：
```
(def u (tarray/new :uint64 2))
(put u 0 9999999999)
(tarray/slice u)   # => @[<core/u64 9999999999> <core/u64 0>]
```

⚠ 型別關鍵字打錯會直接 panic，不是回傳錯誤值：`(tarray/new :int128 3)` => `error: invalid typed array type int128`。

`new` 的第 5 個參數可以是既有 buffer，拿它的一段記憶體來開新 view（配合 stride/offset 做「疊圖」）：
```
(def buf (tarray/buffer 10))
(def view (tarray/new :int8 5 1 2 buf))
(tarray/properties view)  # => {... :byte-offset 2 :size 5 :stride 1 ...}
```

## spork/cmath（4 個，透過 spork/math 雙重掛載）

模逆元（invmod）、模乘（mulmod）、模冪（powmod）、Jacobi 符號（jacobi）是數論／密碼學常用的整數運算：白話說，`invmod a m` 是找一個數 `x` 使得 `a*x ≡ 1 (mod m)`（很像除法但限定在整數的模運算世界裡）；`jacobi` 判斷一個數是不是模 m 的二次剩餘，符號本身較冷門，這裡列出只是求全。

| 函式 | 簽名 | 說明 |
|---|---|---|
| `invmod` | `(math/invmod a m)` | `a` 對 `m` 的模逆元；無解回傳 `math/nan` |
| `jacobi` | `(math/jacobi a m)` | 計算 Jacobi 符號 `(a\|m)`，結果是 `-1` `0` `1` |
| `mulmod` | `(math/mulmod a b m)` | `(a*b) mod m`，避免直接相乘溢位 |
| `powmod` | `(math/powmod a b m)` | `(a^b) mod m`（快速冪），`b` 可為負，等同先取逆元再算正冪 |

⚠ **雙重掛載**：這 4 個函式的原生模組叫 `spork/cmath`，直接 `(import spork/cmath)` 拿到的是 `cmath/invmod` 這種名字；但 `spork/math.janet` 原始碼裡有 `(import spork/cmath :prefix "" :export true)`，把它們無前綴塞進 `spork/math` 的命名空間再匯出，所以 `(import spork/math)` 之後也能直接叫 `math/invmod`。兩邊是同一份 C 函式，行為完全一樣：

```
$ janet -e '(import spork/cmath) (print (cmath/invmod 3 7))'
5
$ janet -e '(import spork/math) (print (math/invmod 3 7)) (print (math/jacobi 1001 9907))'
5
-1
```

其餘實測：
```
(cmath/mulmod 123456789 987654321 1000000007)  # => 259106859
(cmath/powmod 2 10 1000)                       # => 24
(cmath/invmod 2 4)                             # => nan          偶數對偶數模，2 沒有逆元
```

⚠ 回傳型別跟著 `m` 走：`m` 是一般 number 就回 number；`m` 是 `int/s64`／`int/u64` 這種 abstract 整數，回傳也會是同型別的 abstract：
```
(def m (int/s64 1000000007))
(type (math/powmod 2 10 m))  # => core/s64
```

⚠ `a` `b` `m` 都必須是整數，丟浮點數會直接 panic：`(cmath/invmod 3.5 7)` => `error: can not convert number 3.5 to 64 bit signed integer`。

⚠ 這 4 個函式的 docstring 裡簽名寫的是 `math/xxx`（例如 `(doc cmath/invmod)` 印出來簽名是 `(math/invmod a m)`），這是原始碼裡的既有寫法，不代表 `cmath/invmod` 這個名字不能用——兩個名字都真的能呼叫，只是文件字串沒跟著改。

想查 `spork/math` 本身其他函式（矩陣、統計、數論組合等），見：
[math-線性代數.md](math-線性代數.md)｜[math-統計與機率.md](math-統計與機率.md)｜[math-數論與組合.md](math-數論與組合.md)
