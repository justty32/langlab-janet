# 46b · 資料、切片與推導

[← 46 從 Python 過來](46-從-Python-過來.md)

Python 的四種容器、切片語法、三種推導式，在 Janet 各對到什麼。
基礎行為在 [02 資料結構](02-資料結構.md) 跟 [25 序列工具](25-序列工具.md)，這裡只講**差在哪**。

## 四種容器

| Python | Janet | 一句話 |
|---|---|---|
| `[1, 2]` list | `@[1 2]` array | 一樣可變、可 push |
| `(1, 2)` tuple | `[1 2]` tuple | 不可變、可當字典的 key |
| `{"a": 1}` dict | `@{:a 1}` table | key 慣用 keyword，不是字串 |
| `{1, 2}` set | 沒有 | 見下 |

⚠ 括號剛好對調：Python 的 `[]` 是可變的 list，Janet 的 `[]` 是不可變的 tuple。
Janet 用 `@` 前綴表示「可變」，所以可變版都長 `@[...]` `@{...}`。

### 沒有 set，用 table 當 set

值放 `true`，判斷用 `has-key?`：

```janet
(def s (tabseq [x :in [1 2 2 3]] x true))   # @{1 true 2 true 3 true}
(has-key? s 2)   # => true
(length s)       # => 3
```

只是要「去重」的話有現成的：

```janet
(distinct [1 2 2 3])   # => @[1 2 3]
```

⚠ 沒有內建的交集／聯集／差集，自己用 `filter` 寫：
`(filter |(has-key? b $) (keys a))` 就是交集。

## 切片

```janet
(slice [1 2 3 4 5] 1 -2)   # => (2 3 4)
(slice [1 2 3 4 5] 1)      # => (2 3 4 5)
(slice "hello" 1 -2)       # => "ell"
```

⚠ **負索引的語意跟 Python 差一格**。Python 的 `-1` 指最後一個元素，
所以 `a[1:-1]` 砍掉最後一個；Janet 的 `-1` 指「最後一個元素的**後面**」，
所以 `(slice a 1 -1)` 保留到結尾，`(slice a 1 -2)` 才等於 Python 的 `a[1:-1]`。
心法：Janet 的負索引是 `len+1+n`，Python 是 `len+n`。

沒有 `a[::2]` 這種步長語法，要自己 `seq`：

```janet
(seq [i :range [0 6 2]] i)   # => @[0 2 4]
```

`slice` 吃什麼都回 tuple／string；要回 array 用 `array/slice`，要回 string 用 `string/slice`。

## 三種推導

| Python | Janet |
|---|---|
| `[f(x) for x in xs if p(x)]` | `(seq [x :in xs :when (p x)] (f x))` |
| `{x: f(x) for x in xs}` | `(tabseq [x :in xs] x (f x))` |
| `(f(x) for x in xs)`（惰性） | `(generate [x :in xs] (f x))` |
| `[y for x in xs for y in x]` | `(catseq [x :in xs] x)` |

```janet
(seq [x :range [0 5] :when (even? x)] (* x x))   # => @[0 4 16]
(pp (tabseq [x :in [1 2 3]] x (* x x)))          # => @{1 1 2 4 3 9}
(catseq [x :in [1 2]] [x x])                     # => @[1 1 2 2]
```

`generate` 回的是 fiber，真的一個一個算——這是 Janet 唯一的惰性序列：

```janet
(take 3 (generate [x :range [0 100]] (* x x)))   # => @[0 1 4]
```

`:when`／`:while`／`:range`／`:in`／`:keys`／`:pairs` 這些修飾子全表在 [32b](32b-loop-全表.md)。
其它序列函式（`map`／`filter`／`reduce`）全是 eager，沒有 Python 3 那種「回 iterator」的行為。

## 內建函式對照

| Python | Janet | 實測 |
|---|---|---|
| `enumerate(xs)` | `(pairs xs)` | `@[(0 :a) (1 :b)]` |
| `zip(a, b)` | `(map tuple a b)` | `@[(1 :a) (2 :b)]` |
| `dict(zip(k, v))` | `(zipcoll k v)` | `@{:a 1 :b 2}` |
| `sorted(xs)` | `(sorted xs)` | 回新 array |
| `sorted(xs, key=f)` | `(sorted-by f xs)` | |
| `xs.sort()` | `(sort xs)` | 原地改 |
| `reversed(xs)` | `(reverse xs)` | 回新 array |
| `sum(xs)` | `(sum xs)` | |
| `any(xs)` | `(some truthy? xs)` | |
| `all(p(x) for x in xs)` | `(all p xs)` | |
| `min(xs)` | `(min ;xs)` | ⚠ 要 splice |
| `min(xs, key=f)` | `(extreme (fn [a b] (< (f a) (f b))) xs)` | |
| `len(xs)` | `(length xs)` | |
| `xs.count(...)` | `(count p xs)` | 吃的是**述詞**不是值 |

```janet
(pairs [:a :b :c])                    # => @[(0 :a) (1 :b) (2 :c)]
(map tuple [1 2 3] [:a :b :c])        # => @[(1 :a) (2 :b) (3 :c)]
(sorted-by length ["aaa" "b" "cc"])   # => @["b" "cc" "aaa"]
(all even? [2 4])                     # => true
(count even? [1 2 3 4])               # => 2
```

⚠ `min`／`max` 吃的是**多個參數**不是一個序列，所以要 `(min ;xs)`；
`sum`／`product` 反過來吃序列。這對不齊的地方很容易寫錯。

⚠ `(some even? [1 3 4])` 回的是**述詞的回傳值**不是元素：`true`。
想拿到元素本身用 `(find even? xs)`。

## `in` 怎麼寫

| Python | Janet |
|---|---|
| `x in list` | `(has-value? xs x)` |
| `list.index(x)` | `(index-of x xs)` |
| `k in dict` | `(has-key? d k)` |
| `"ab" in "xaby"` | `(string/find "ab" "xaby")` → 索引或 nil |

```janet
(has-value? [1 2 3] 2)          # => true
(index-of 2 [1 2 3])            # => 1
(string/find "ell" "hello")     # => 1
```

⚠ `index-of` 的參數順序是「值在前、序列在後」，跟 `has-value?` 相反。

下一步：[46c-Python-字典與字串.md](46c-Python-字典與字串.md)。
