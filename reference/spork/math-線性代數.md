# spork/math ・ 線性代數

[← spork 索引](README.md)｜[← reference 索引](../README.md)

⚠ **別跟內建 `math/*` 搞混**：內建 `math/*`（見 [../math-數學與隨機.md](../math-數學與隨機.md)）是純量數學（sin、sqrt、常數）。這裡的 `spork/math` 匯入後也叫 `math/*`，但做的是**線性代數（矩陣＝巢狀 array）＋統計＋數論**，兩者是完全不同的模組，同名只是巧合：

```
$ janet -e '(import spork/math) (def m [[1 2] [3 4]]) (print (math/det m)) (print (math/matmul m m))'
-2
<array 0x...>
```

（`print` 對 array 只印位址，本檔範例一律用 `pp`。另外 `math/invmod` `math/jacobi` `math/mulmod` `math/powmod` 這 4 個其實是 `spork/cmath` 被匯入進 `math/` 命名空間的，文檔見 [tarray-cmath.md](tarray-cmath.md)，不在本檔重複列。）

矩陣一律用「巢狀 array」表示，`m 0` 是第一列（row-major）。`(math/ident 3)` 是 `3x3`；`(zero c &opt r)` 的 `c` 是**每列長度**、`r` 是**列數**（`(zero 2 3)` 會給 3 列、每列 2 個元素）。

## 建構與形狀

| 函式 | 簽名 | 說明 |
|---|---|---|
| `ident` | `(ident c)` | `c x c` 單位矩陣 |
| `zero` | `(zero c &opt r)` | 長度 `c` 的零向量；給 `r` 則是 `r` 列、每列長度 `c` 的零矩陣 |
| `scalar` | `(scalar c s)` | `c x c`，對角線是 `s`、其餘 0 |
| `unit-e` | `(unit-e n k)` | `n` 維單位向量，第 `k` 個分量是 1 |
| `size` | `(size m)` | `(rows m) (cols m)` 兩元素 tuple |
| `rows` / `cols` | `(rows m)` / `(cols m)` | 列數／欄數（`cols` 靠第一列長度推算） |
| `get-only-el` | `(get-only-el m)` | 巨集，取 `1x1` 矩陣裡唯一的元素 |
| `copy` | `(copy xs)` | 複製陣列（tarray 則用 `:slice`）；⚠ 只淺拷貝最外層，見下方警告 |
| `swap` | `(swap arr i j)` | 原地交換陣列裡 `i`、`j` 兩個位置 |

## 基本運算

| 函式 | 簽名 | 說明 |
|---|---|---|
| `add` | `(add m a)` | `m` 加上純量或同形矩陣 `a`，**mutate `m`** |
| `subtract` | `(subtract v1 v2)` | 向量逐項相減，回傳新陣列（不 mutate） |
| `mul` | `(mul m a)` | `a` 是純量：純量乘；`a` 是矩陣：逐項相乘（Hadamard）；`a` 是純數字陣列（向量）：當欄向量做真矩陣乘法。**mutate `m`** |
| `matmul` | `(matmul ma mb)` | 真正的矩陣乘法，回傳新矩陣，不 mutate |
| `scale` | `(scale v k)` | 向量 `v` 每項乘上 `k`，回傳新陣列 |
| `dot` / `dot-fast` | `(dot v1 v2)` | 兩向量點積；`dot-fast` 假設等長、省檢查 |
| `outer` | `(outer v1 v2)` | 外積，回傳矩陣 `m[i][j] = v1[i]*v2[j]` |
| `sop` | `(sop m op & a)` | 對 `m` 每格套 `(op cell ;a)`，**mutate** |
| `mop` | `(mop m op a)` | 對 `m` 每格套 `(op cell a[同位置])`，**mutate** |
| `sign` | `(sign x)` | 回傳 `-1` / `0` / `1` |
| `trans` | `(trans m)` | 轉置，回傳新矩陣 |
| `normalize-v` | `(normalize-v xs)` | 除以歐氏長度（L2 norm），回傳單位向量 |

## 裁切、拼接、變形

| 函式 | 簽名 | 說明 |
|---|---|---|
| `row->col` | `(row->col xs)` | 一維數字陣列轉直行矩陣；已經是二維就原樣回傳 |
| `squeeze` | `(squeeze m)` | 把所有列接成一維陣列 |
| `slice-m` | `(slice-m m rslice cslice)` | 依列、欄的 slice 範圍 `[start end]` 截取子矩陣 |
| `fliplr` / `flipud` | `(fliplr m)` / `(flipud m)` | 左右／上下鏡像 |
| `join-rows` | `(join-rows m1 m2)` | 垂直疊列（列數相加） |
| `join-cols` | `(join-cols m1 m2)` | 水平併欄（欄數相加） |
| `expand-m` | `(expand-m n m)` | 把 `m` 嵌進 `n x n` 單位矩陣的右下角 |

## 分解、行列式、比較

| 函式 | 簽名 | 說明 |
|---|---|---|
| `det` | `(det m)` | 行列式（方陣），遞迴按第一列展開 |
| `perm` | `(perm m)` | permanent（跟 det 很像但展開時不交錯正負號），冷門，統計上偶爾用到 |
| `minor` | `(minor m x y)` | 拿掉第 `x` 列、第 `y` 欄後的子矩陣 |
| `qr` / `qr1` | `(qr m)` / `(qr1 m)` | QR 分解（用 Householder 反射法把矩陣拆成正交矩陣 `Q` 與上三角矩陣 `R`）。`qr1` 是內部單步版。不懂線代細節可以先跳過，這裡列出來求全 |
| `svd` | `(svd m &opt n-iter)` | 奇異值分解（靠反覆 QR 逼近），回傳 `{:U :S :V}`，`n-iter` 預設 100 |
| `approx-eq` | `(approx-eq a e &opt t)` | 純量近似相等，容差 `t` 預設 `epsilon` |
| `m-approx=` | `(m-approx= m1 m2 &opt tolerance)` | 矩陣逐格 `approx-eq` |
| `relative-err` | `(relative-err a e)` | `\|a-e\|/e`（`a`、`e` 都是 0 時回 0） |
| `epsilon` | 數字 `0.0001` | 上面幾個函式的預設容差 |

## 實測範例

```
(import spork/math)
(pp (math/ident 3))        # => @[@[1 0 0] @[0 1 0] @[0 0 1]]
(pp (math/zero 2 3))        # => @[@[0 0] @[0 0] @[0 0]]        c=2 每列長度，r=3 列數
(pp (math/scalar 3 5))      # => @[@[5 0 0] @[0 5 0] @[0 0 5]]
(pp (math/size [[1 2][3 4]]))   # => (2 2)
(pp (math/trans [[1 2][3 4]]))  # => @[@[1 3] @[2 4]]
(pp (math/matmul [[1 2][3 4]] [[1 2][3 4]]))  # => @[@[7 10] @[15 22]]
(pp (math/outer [1 2] [3 4]))   # => @[@[3 4] @[6 8]]
(pp (math/unit-e 4 1))          # => @[0 1 0 0]
```

⚠ **型別判斷認的是 `:array`（`@[...]`），不是 `:tuple`（`[...]`）**：`add`／`mul` 內部用 `(case (type a) :array ...)` 分派，第二個參數若寫成字面量 `[[1 1][1 1]]`（tuple）就**不會**匹配 `:array` 分支，直接回傳 `nil`！要用 `@[@[1 1] @[1 1]]`：

```
(math/add @[@[1 2] @[3 4]] [[1 1][1 1]])       # => nil，因為 [[1 1]...] 是 tuple
(math/add @[@[1 2] @[3 4]] @[@[1 1] @[1 1]])   # => @[@[2 3] @[4 5]]  正確
(math/mul @[@[1 2] @[3 4]] @[@[1 0] @[0 1]])   # => @[@[1 0] @[0 4]]  注意！是逐項相乘不是矩陣乘法
(math/mul @[@[1 2] @[3 4]] @[1 1])             # => @[@[3] @[7]]      純數字陣列才走「當欄向量真矩陣乘」
```

⚠ **`copy` 只是淺拷貝最外層**：對巢狀矩陣，內層的列還是共用同一個 array，改子矩陣的格子會連原矩陣一起改到：

```
(def m @[@[1 2] @[3 4]])
(def m2 (math/copy m))
(put (m2 0) 0 999)
(pp m)   # => @[@[999 2] @[3 4]]   原矩陣也被改了！
```

⚠ `qr`／`svd` 這份實作對非方陣（例如 3 列 2 欄）在某些形狀下會直接噴錯（`map` 引數不對），穩妥的用法是限定方陣；真的要對長方矩陣做分解，先自行確認形狀能跑過再用。
