# 46c · 字典方法與字串

[← 46 從 Python 過來](46-從-Python-過來.md)

`dict.get`、`Counter`、`groupby`、f-string、`"".join(...)`——Python 用得最順手的那批，
在 Janet 各叫什麼。字串的完整行為見 [18](18-字串與-buffer.md)，字典走訪見 [35b](35b-走訪與改寫巢狀資料.md)。

## 字典方法

| Python | Janet | 備註 |
|---|---|---|
| `d[k]` | `(d k)` 或 `(in d k)` | 字典本身就能當函式呼叫 |
| `d.get(k)` | `(get d k)` | 沒有就 `nil` |
| `d.get(k, 0)` | `(get d k 0)` | 第三個參數是預設值 |
| `d[k] = v` | `(put d k v)` | 回傳 `d` 本身，可以串 |
| `del d[k]` | `(put d k nil)` | ⚠ 存 nil ＝ 刪除 |
| `d.keys()` / `.values()` | `(keys d)` / `(values d)` | 回 array |
| `d.items()` | `(pairs d)` | 回 `@[(k v) ...]` |
| `d.update(e)` | `(merge-into d e)` | `(merge a b)` 回新的 table |
| `d.setdefault(k, [])` | 見下 | 沒有單一函式 |
| `{**a, **b}` | `(merge a b)` | |
| `collections.Counter(xs)` | `(frequencies xs)` | |
| `collections.defaultdict` | 見下 | |
| `itertools.groupby` | `(group-by f xs)` | ⚠ 不用先排序 |

```janet
(get {:a 1} :b 0)    # => 0
(in {:a 1} :a)       # => 1
(update @{:a 1} :a inc)   # => @{:a 2}
```

`update` 是 Python 沒有的：直接對某個 key 套一個函式。
要更深的用 `update-in`／`get-in`／`put-in`，等於 Python 那串 `d["a"]["b"]`。

### setdefault 與 defaultdict

Janet 沒有這兩樣，寫法都是同一招——「沒有就先塞一個」：

```janet
(defn ensure [d k mk] (or (get d k) (get (put d k (mk)) k)))
(def d @{})
(array/push (ensure d :xs array) 1)
(array/push (ensure d :xs array) 2)
(get d :xs)   # => @[1 2]
```

`defaultdict(list)` 的場景八成其實是 `group-by`，先看看能不能直接用它。

### Counter 與 groupby

```janet
(pp (frequencies [:a :b :a]))                  # => @{:a 2 :b 1}
(pp (group-by |(mod $ 3) [1 2 3 4 5 6]))       # => @{0 @[3 6] 1 @[1 4] 2 @[2 5]}
```

⚠ 跟 Python 的 `itertools.groupby` 差很多：Python 那個只切**相鄰**的同組，
所以要先 `sorted`；Janet 的 `group-by` 掃全部、直接給你一個 key → array 的 table。
要 Python 那種「切相鄰」的行為用 `partition-by`：

```janet
(partition-by even? [2 4 1 3 6])   # => @[@[2 4] @[1 3] @[6]]
```

`Counter.most_common()` 沒有現成的，`(sorted-by |(- ((frequencies xs) $)) (keys ...))` 自己排。

## 字串

| Python | Janet |
|---|---|
| `f"{name} has {n}"` | `(string/format "%s has %d" name n)` |
| `"a" + str(1)` | `(string "a" 1)` |
| `f"{x:.2f}"` | `(string/format "%.2f" x)` |
| `repr(x)` | `(string/format "%q" x)` |
| `",".join(xs)` | `(string/join xs ",")` |
| `s.split(",")` | `(string/split "," s)` |
| `s.split()` | 沒有；自己切空白或用 PEG |
| `s.strip()` | `(string/trim s)` |
| `s.strip("x")` | `(string/trim s "x")` |
| `s.startswith(p)` | `(string/has-prefix? p s)` |
| `s.endswith(p)` | `(string/has-suffix? p s)` |
| `s.replace(a, b)` | `(string/replace-all a b s)` |
| `s.upper()` | `(string/ascii-upper s)` |
| `s * 3` | `(string/repeat s 3)` |
| `s.find(t)` | `(string/find t s)` |

```janet
(string/format "%s has %d" "Bob" 3)   # => "Bob has 3"
(string "a" 1 :b)                     # => "a1b"
(string/join ["a" "b"] ",")           # => "a,b"
(string/split "," "a,b,c")            # => @["a" "b" "c"]
(string/trim "  hi  ")                # => "hi"
(string/has-prefix? "he" "hello")     # => true
(string/replace "l" "L" "hello")      # => "heLlo"
(string/replace-all "l" "L" "hello")  # => "heLLo"
```

⚠ 三個順序陷阱，全都跟 Python 的 `s.method(arg)` 相反：
`string/join` 是**序列在前**、`string/split`／`string/find`／`has-prefix?` 是**要找的東西在前**、
`string/replace` 是 `舊 新 原字串`。只有 `string/trim` 是字串在前。

⚠ `string/replace` 只換第一個，`replace-all` 才是 Python `.replace()` 的行為。

### 多行與 raw 字串

Python 的 `"""..."""` 與 `r"..."` 在 Janet 是同一個東西——反引號長字串。
它既是多行、又不處理跳脫：

```janet
(length "C:\new")     # => 5
(length ``C:\new``)   # => 6
```

`"C:\new"` 裡的 `\n` 是換行字元；`` `C:\new` `` 裡的 `\` 就是反斜線本身。
反引號可以用一個以上，只要前後數量相同，內容裡就能放反引號。
沒有 `.dedent()`，縮排會原樣留著。

### 格式化沒有 `.format()`

`string/format` 只有 C 那套 `%s %d %f %q %j %p`，**沒有** `{}`、沒有具名欄位。
要拼很多欄位時多半是直接用 `(string ...)`，或寫個小巨集。完整動詞表在 [18](18-字串與-buffer.md)。

下一步：[46d-Python-函式.md](46d-Python-函式.md)。
