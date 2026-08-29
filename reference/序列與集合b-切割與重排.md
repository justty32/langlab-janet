# 序列與集合 ・ 切割與重排

[← reference 索引](README.md)

本檔收「切割」「排序」「去重／分組／分塊」「長度與型別判斷」四節，是 [序列與集合.md](序列與集合.md) 的延伸（總覽與轉換／篩選／聚合在那份）。對應教學 docs/25-序列工具.md。

## 切割

| 函式 | 簽名 | 說明 |
|---|---|---|
| `take` | `(take n ind)` | 取前 n 個；`n` 是負的就從尾巴取 |
| `take-while` | `(take-while pred ind)` | 從頭取到第一個不滿足 `pred` 為止 |
| `take-until` | `(take-until pred ind)` | 等於 `(take-while (complement pred) ind)` |
| `drop` | `(drop n ind)` | 丟掉前 n 個；負的從尾巴丟 |
| `drop-while` / `drop-until` | 同上 take 系列，反過來 | 丟到第一個不滿足／滿足為止 |
| `slice` | `(slice x &opt start end)` | 任意起訖切片，支援負索引 |
| `first` / `last` | `(first xs)` / `(last xs)` | 取頭／尾，空序列回 `nil` |

⚠ 負索引怎麼算：`(slice [1 2 3 4 5] 1 -2)` → `(2 3 4)`——`-2` 相當於「從尾巴數來第 2 個位置」（`-1`＝結尾之後、`-2`＝最後一個元素的位置），所以是切到「倒數第二個之前」，也就是留到 `4`。

```
(take -2 [1 2 3 4 5])                   # => (4 5)
(slice [1 2 3 4 5] 1 -2)                # => (2 3 4)
(slice [1 2 3 4 5] -3 -1)               # => (4 5)
```

## 排序與反轉

| 函式 | 簽名 | 說明 |
|---|---|---|
| `sort` | `(sort ind &opt before?)` | **原地**排序、回傳同一個陣列，不穩定排序（quick-sort） |
| `sorted` | `(sorted ind &opt before?)` | 回傳**新**陣列，原陣列不動 |
| `sort-by` | `(sort-by f ind)` | 原地，依 `(f x)` 的結果排 |
| `sorted-by` | `(sorted-by f ind)` | 回新陣列版的 `sort-by` |
| `reverse` | `(reverse ind)` | 回傳**新**的、順序顛倒的陣列 |
| `reverse!` | `(reverse! ind)` | **原地**顛倒，回傳同一個陣列 |

⚠ 命名不對稱：排序是「`sort` 原地／`sorted` 回新的」，反轉卻是
「`reverse` 回新的／`reverse!` 原地」——**`!` 才代表原地**，`sort` 是唯一的例外。

```
(def a @[3 1 2]) (sort a)               # a 變成 @[1 2 3]（原地改）
(def b @[3 1 2]) (sorted b) (pp b)      # => @[3 1 2]（sorted 不動原本的 b）
(pp (reverse @[1 2 3]))                 # => @[3 2 1]
(def c @[1 2 3]) (reverse! c) (pp c)    # => @[3 2 1]（原地）
(pp (reverse "abc"))                    # => @"cba"  ← 字串進，buffer 出（不是 array）
```

## 去重／分組／分塊

| 函式 | 簽名 | 說明 |
|---|---|---|
| `distinct` | `(distinct xs)` | 去重，回新陣列 |
| `frequencies` | `(frequencies ind)` | 數每個值出現幾次，回 table |
| `group-by` | `(group-by f ind)` | 依 `(f x)` 的結果分組成 table，值是陣列 |
| `partition` | `(partition n ind)` | 每 n 個切一塊，回傳陣列包 tuple |
| `partition-by` | `(partition-by f ind)` | 依 `(f x)` 變化時切塊，回傳陣列包**陣列**（跟 partition 的內層型別不同） |
| `interleave` | `(interleave & cols)` | 多個序列交錯取值：各自第一個、各自第二個⋯ |
| `interpose` | `(interpose sep ind)` | 元素間插入 `sep` |
| `flatten` / `flatten-into` | `(flatten xs)` / `(flatten-into into xs)` | 巢狀陣列深度優先展平；`-into` 版本接到既有陣列後面 |
| `range` | `(range & args)` | 產生 `[start,end)` 整數陣列，可帶 step |

⚠ `(frequencies "hello")` 的 key 是 **byte 數字**不是字元字串（字串的元素本來就是 byte）：

```
(frequencies "hello")                   # => @{101 1 104 1 108 2 111 1}   (101=e 104=h 108=l 111=o)
```

⚠ `partition` 最後一塊會短，且內層是 **tuple**；`partition-by` 內層是 **array**：

```
(partition 2 [1 2 3 4 5])               # => @[(1 2) (3 4) (5)]      內層是 tuple，最後一塊只剩 1 個
(partition-by even? [2 4 5 7 8 8])      # => @[@[2 4] @[5 7] @[8 8]]  內層是 array
(interleave [1 2 3] [:a :b :c])         # => @[1 :a 2 :b 3 :c]
(interpose 0 [1 2 3])                   # => @[1 0 2 0 3]
(flatten [1 [2 [3 4] 5] 6])             # => @[1 2 3 4 5 6]
(range 2 5)                             # => @[2 3 4]
(range 0 10 2)                          # => @[0 2 4 6 8]
```

## 長度、存取與型別判斷

| 函式 | 簽名 | 說明 |
|---|---|---|
| `empty?` | `(empty? iter)` | 是否為空 |
| `length` | `(length ds)` | 長度／個數（table、struct 回 key-value 對數） |
| `lengthable?` | `(lengthable? x)` | 是 bytes／indexed／dictionary 之一嗎 |
| `indexed?` | `(indexed? x)` | 是 array 或 tuple 嗎 |
| `dictionary?` | `(dictionary? x)` | 是 table 或 struct 嗎 |
| `bytes?` | `(bytes? x)` | 是 string／symbol／keyword／buffer 嗎 |
| `get` | `(get ds key &opt dflt)` | 安全存取，找不到回 `dflt`（不報錯） |
| `in` | `(in ds key &opt dflt)` | 跟 `get` 幾乎一樣，但**索引型態越界會直接報錯**，不是回 `dflt` |
| `next` | `(next ds &opt key)` | 疊代用：給目前 key 找下一個，給 `nil` 拿第一個，到底回 `nil` |

⚠ `in` 和 `get` 不是同義詞：`(get [1 2 3] 5 :dflt)` 安全回傳 `:dflt`，但 `(in [1 2 3] 5)` 直接丟 `error: expected integer key for tuple in range [0, 3), got 5`。字典型態（table/struct）兩者行為才一致。

```
(get [1 2 3] 5 :dflt)                   # => :dflt
(in [1 2 3] 1)                          # => 2
(next {:a 1 :b 2})                      # => :b   (table 內部順序，不保證跟寫入順序一致)
(next {:a 1 :b 2} :b)                   # => :a   (接著疊代)
(next {:a 1 :b 2} :a)                   # => nil  (疊代到底)
```
