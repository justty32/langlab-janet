# spork/misc ・ 順手工具（下：陣列排序搜尋／資料表）

[← spork 索引](README.md)｜[← reference 索引](../README.md)

接續 [misc-順手工具.md](misc-順手工具.md)，本檔收 `spork/misc` 剩下的 21 個綁定：
陣列取值／排序搜尋、以及「資料表」（data-frame）操作。全部一樣用
`(import spork/misc :prefix "")` 測過。

## 陣列取值

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `second` | `(second xs)` | 第二個元素（index 1） |
| `third` | `(third xs)` | 第三個元素（index 2） |
| `penultimate` | `(penultimate xs)` | 倒數第二個 |
| `antepenultimate` | `(antepenultimate xs)` | 倒數第三個（幾乎用不到，列在這裡是為了完整） |

## 排序與搜尋（要求陣列已排序）

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `binary-search` | `(binary-search x arr &opt <?)` | 二分搜尋：`arr` 必須已排序，找 `x` 的位置；找不到就回傳「該插入的位置」 |
| `binary-search-by` | `(binary-search-by x arr f)` | 同 `binary-search`，但排序依據是 `(f 元素)` 的值 |
| `insert-sorted` | `(insert-sorted arr <? & xs)` | 把 `xs` 逐一插入已排序的 `arr`，維持排序（就地修改，回傳 `arr`） |
| `insert-sorted-by` | `(insert-sorted-by arr f & xs)` | 同上，排序依據是 `(f 元素)` |
| `merge-sorted` | `(merge-sorted a b &opt <?)` | 合併兩個已排序陣列成一個新的已排序陣列 |
| `merge-sorted-by` | `(merge-sorted-by a b f)` | 同上，排序依據是 `(f 元素)` |
| `randomize-array` | `(randomize-array arr &opt rng)` | 用 Fisher-Yates 演算法就地打亂陣列，可給自訂 RNG |

## 資料表（data-frame）

⚠ 這裡的「資料表」跟直覺可能不同：**是欄位導向**（一個 table，key 是欄名，值是該欄所有資料的陣列），
**不是**「一堆列（row）組成的陣列」。例如 `@{:name @["Alice" "Bob"] :age @[30 25]}` 才是合法輸入，
`[@{:name "Alice" :age 30} ...]`（一列一個 table）會直接報錯。

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `select-keys` | `(select-keys data keyz)` | 只留 `data` 裡 `keyz` 列出的那幾個 key |
| `table-filter` | `(table-filter pred dict)` | 留下 `(pred k v)` 為真的 key-value 對 |
| `map-keys` | `(map-keys f data)` | 對 table 的每個 key 套 `f`（值不動），會遞迴進巢狀 table |
| `map-keys-flat` | `(map-keys-flat f data)` | 同 `map-keys`，但不遞迴（只動最外層） |
| `map-vals` | `(map-vals f data)` | 對 table 的每個 value 套 `f`（key 不動） |
| `gett` | `(gett ds & keyz)` | 遞迴版 `get`：`(gett t :a :b)` 等同 `(get-in t [:a :b])` |
| `column-combine` | `(column-combine data-frame out-column input-columns combine-row &opt drop-input-columns)` | 把 `input-columns` 幾欄的值餵給 `combine-row`，結果存成新的一欄 `out-column` |
| `pivot` | `(pivot data-frame row-col col-col value-col &opt reducer reduce-init)` | 樞紐分析：把「列/欄/值」三欄攤開成「一列一個列值、每個欄值變成一欄」的新資料表 |
| `format-table` | `(format-table buf-into data &opt columns header-mapping column-mapping)` | 跟 `print-table` 一樣排版，但寫進 buffer 而不是印出來 |
| `print-table` | `(print-table data &opt columns header-mapping column-mapping)` | 把資料表印成好讀的方框表格 |

## 實測範例

```janet
(import spork/misc :prefix "")

(second [1 2 3 4])          # => 2
(third [1 2 3 4])           # => 3
(penultimate [1 2 3 4])     # => 3
(antepenultimate [1 2 3 4]) # => 2

(binary-search 5 [1 3 5 7 9])  # => 2   找到，位置 2
(binary-search 4 [1 3 5 7 9])  # => 2   沒找到，回傳「4 該插入的位置」（在 3 和 5 之間）

(def a @[1 3 5 7])
(insert-sorted a < 4)
a  # => @[1 3 4 5 7]

(merge-sorted @[1 3 5] @[2 4 6])  # => @[1 2 3 4 5 6]

(def r (math/rng 1))
(randomize-array @[1 2 3 4 5] r)  # => @[1 4 2 3 5]（固定種子下的結果，會依 rng 不同而變）
```

```janet
(select-keys @{:a 1 :b 2 :c 3} [:a :c])          # => @{:a 1 :c 3}
(table-filter (fn [k v] (> v 1)) @{:a 1 :b 2 :c 3}) # => @{:b 2 :c 3}
(map-keys string @{:a 1 :b 2})                    # => @{"a" 1 "b" 2}
(map-vals inc @{:a 1 :b 2})                       # => @{:a 2 :b 3}
(gett @{:a @{:b 1}} :a :b)                        # => 1
```

資料表三兄弟（欄位導向，注意都要用可變陣列 `@[]`）：

```janet
(def df @{:first @["A" "B"] :last @["Smith" "Jones"]})
(column-combine df :full [:first :last] (fn [vs] (string (vs 0) " " (vs 1))))
df  # => @{:first @["A" "B"] :full @["A Smith" "B Jones"] :last @["Smith" "Jones"]}

(def df2 @{:r @["x" "x" "y"] :c @["a" "b" "a"] :v @[1 2 3]})
(pivot df2 :r :c :v)
# => @{"a" @[1 3] "b" @[2 nil] :r @["x" "y"]}
#    列 x 有 a=1 b=2，列 y 只有 a=3（沒出現的 col 補 nil）

(print-table [@{:name "Alice" :age 30} @{:name "Bob" :age 25}] [:name :age] @{:name "Name" :age "Age(yrs)"})
```
```
╭─────┬────────╮
│ Name│Age(yrs)│
╞═════╪════════╡
│Alice│      30│
│  Bob│      25│
╰─────┴────────╯
```

⚠ 注意 `print-table` 傳的第一個引數（`data`）用的是**一列一個 table 的陣列**（`[@{...} @{...}]`），
跟 `column-combine`／`pivot` 要的欄位導向格式**不是同一種**——三個函式都叫「資料表工具」，
但 `print-table`／`format-table` 吃 row-oriented，`column-combine`／`pivot` 吃 column-oriented，用之前看清楚。
