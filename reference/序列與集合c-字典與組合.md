# 序列與集合 ・ 字典、組合函式、走訪

[← reference 索引](README.md)

本檔收「字典操作」「組合函式」「走訪／迴圈」三節，接續 [序列與集合.md](序列與集合.md)（總覽在那份，另有 [序列與集合b-切割與重排.md](序列與集合b-切割與重排.md)）。對應教學 docs/25-序列工具.md。

## 字典操作（table／struct）

| 函式 | 簽名 | 說明 |
|---|---|---|
| `pairs` | `(pairs x)` | 取出 `[k v]` 對的陣列 |
| `kvs` | `(kvs dict)` | 取出**扁平**的 `@[k v k v ...]` |
| `keys` / `values` | `(keys x)` / `(values x)` | 只要鍵／只要值 |
| `invert` | `(invert ds)` | key、value 互換；多個 key 對到同個 value 時只留其中一個 |
| `merge` | `(merge & colls)` | 多個 table/struct 合併成**新** table，後面蓋前面 |
| `merge-into` | `(merge-into tab & colls)` | 合併進**既有**的 `tab`（原地），回傳 `tab` |
| `zipcoll` | `(zipcoll ks vs)` | 兩個陣列拉鍊成 table：`ks[i]` 當 key、`vs[i]` 當 value |
| `from-pairs` | `(from-pairs ps)` | `pairs` 的反運算：`[[k v] ...]` 轉回 table |
| `get-in` / `put-in` / `update-in` | `(get-in ds ks &opt dflt)` 等 | 用一串 key 路徑深入巢狀結構讀／寫／更新，中間缺的層會自動補 table |
| `update` | `(update ds key func & args)` | 對 `ds[key]` 套 `func` 換掉，回傳 `ds` |
| `put` | `(put ds key value)` | 通用的可變賦值：table／array／buffer 都能用，array/buffer 超界會自動撐大 |
| `each` / `eachk` / `eachp` | `(each x ds & body)` 等 | 迴圈跑值／跑鍵／跑 `[k v]` 對，回傳 `nil`（純副作用用） |

⚠ `kvs` 回傳的順序是 table **內部儲存順序**，不保證跟你 put 進去的順序一樣：

```
(kvs {:a 1 :b 2})                       # => @[:b 2 :a 1]     順序不保證，這裡剛好 :b 先
(invert {:a 1 :b 2})                    # => @{1 :a 2 :b}
(zipcoll [:a :b :c] [1 2 3])            # => @{:a 1 :b 2 :c 3}
(merge {:a 1} {:b 2} {:a 3})            # => @{:a 3 :b 2}     後面的 :a 3 蓋掉前面
```

```
(def d @{})
(put-in d [:a :b] 5) (pp d)             # => @{:a @{:b 5}}    中間的 :a 是自動補出來的 table
(def e @{:a @{:n 1}})
(update-in e [:a :n] inc) (pp e)        # => @{:a @{:n 2}}
```

## 組合函式

| 函式 | 簽名 | 說明 |
|---|---|---|
| `juxt` | `(juxt & funs)` | 並聯：把多個函式包成一個，一次呼叫回傳「各自結果」的 tuple（`juxt` 是巨集版，較快） |
| `juxt*` | `(juxt* & funs)` | 同上，一般函式版 |
| `comp` | `(comp & functions)` | 複合：`(comp f g)` 等於「先 g 再 f」 |
| `partial` | `(partial f & more)` | 偏應用：先固定前幾個參數，回傳等之後再餵剩下參數的函式 |
| `complement` | `(complement f)` | 回傳結果取反的新函式 |
| `identity` | `(identity x)` | 原封不動回傳自己，常拿來當「不轉換」的預設函式用 |

```
((juxt + - * /) 6 2)                    # => (8 4 12 3)   四個函式各自套用 6 2，結果併成一個 tuple
((comp inc (fn [x] (* x 2))) 5)         # => 11           先乘 2 得 10，再 inc 得 11
(def add5 (partial + 5)) (add5 10)      # => 15
((complement even?) 3)                  # => true
```

## 走訪／迴圈

| 函式 | 簽名 | 說明 |
|---|---|---|
| `walk` | `(walk f form)` | 只對**最外層**元素套 `f`，不遞迴進巢狀結構 |
| `prewalk` | `(prewalk f form)` | 前序走訪：先對自己套 `f`，才遞迴進子結構 |
| `postwalk` | `(postwalk f form)` | 後序走訪：先遞迴處理完子結構，才對自己套 `f` |

⚠ `walk` 是淺的、`prewalk`／`postwalk` 才會遞迴進巢狀陣列／table 內部：

```
(walk (fn [x] (if (number? x) (* x 10) x)) [1 [2 3] 4])
                                         # => (10 (2 3) 40)     內層 (2 3) 完全沒被碰到
(prewalk (fn [x] (if (number? x) (* x 10) x)) [1 [2 3] 4])
                                         # => (10 (20 30) 40)   遞迴進去了
```
