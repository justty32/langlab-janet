# 46 · 從 Python 過來

你已經會 Python，缺的不是寫程式，是**把手上的習慣對到 Janet 的名字**，
外加知道哪幾條 Python 直覺在這裡會直接害你。這篇是總覽：一張對照表、六個坑、
以及後面五篇的入口。

寫 Janet 最大的心態調整只有一句：**Python 有很多語法糖，Janet 只有函式跟巨集。**
`[x*2 for x in xs]` 在 Python 是語法，在 Janet 是 `seq` 這個巨集；
`with` 是語法，在 Janet 也是巨集。差別在於你自己也能寫一個（見 [08](08-巨集-macro.md)）。

## 一張對照表

| Python | Janet | 備註 |
|---|---|---|
| `x = 1`（可再指派） | `(var x 1)` `(set x 2)` | `(def x 1)` 綁死不能改 |
| `[1, 2, 3]` list | `@[1 2 3]` array | 可變 |
| `(1, 2, 3)` tuple | `[1 2 3]` tuple | 不可變。⚠ 括號種類跟 Python 剛好對調 |
| `{"a": 1}` dict | `@{:a 1}` table | 可變；不可變版是 `{:a 1}` struct |
| `{1, 2}` set | 沒有 | 用 `@{1 true 2 true}`，見 [46b](46b-Python-資料與推導.md) |
| `a[1:-1]` | `(slice a 1 -1)` | ⚠ 負索引語意不同，見 46b |
| `[f(x) for x in xs if p(x)]` | `(seq [x :in xs :when (p x)] (f x))` | 見 46b |
| `{k: v for ...}` | `(tabseq [...] k v)` | 同上 |
| `(f(x) for x in xs)` generator | `(generate [x :in xs] (f x))` | 回 fiber，見 [09](09-fiber.md) |
| `lambda x: x*2` | `(fn [x] (* x 2))` 或 `\|(* $ 2)` | |
| `def f(a, b=1, *args, **kw)` | `(defn f [a &opt b] ...)`／`& rest`／`&keys` | 見 [46d](46d-Python-函式.md) |
| `f(*xs)` / `f(**kw)` | `(f ;xs)` / `(f ;(kvs kw))` | `;` 是 splice |
| `try/except/finally` | `try` ／ `defer` | 見 [46e](46e-Python-錯誤與物件.md) |
| `with open(p) as f:` | `(with [f (file/open p)] ...)` | 見 [20b](20b-資源管理.md) |
| `class C:` + `self` | table ＋ prototype，`(:method obj)` | 見 [22](22-原型與方法.md) |
| `@dataclass` | struct `{:x 1 :y 2}` | 不可變、比值相等 |
| `import x as y` | `(import x :as y)` | 見 [05e](05e-import-與模組路徑.md) |
| `if __name__ == "__main__"` | `(defn main [& args] ...)` | 見 [46f](46f-Python-工具鏈.md) |
| `print(x, file=sys.stderr)` | `(eprint x)` | |
| `re` | PEG（或 spork/regex）| 見 [14](14-peg.md) |
| `threading` / `asyncio` | `ev/` | 見 [15](15-ev-channel-net.md) |

## 六個一定會踩的坑

### ① 縮排不代表任何東西

Janet 靠括號決定結構，換行與縮排純粹給人看。
好處是複製貼上不會爛；代價是你得讓編輯器幫你配對括號（見 [06](06-編輯器與-REPL.md)）。

### ② `0`、`""`、`[]` 全都是**真**

只有 `nil` 和 `false` 是假。這條害人的頻率遠高於其它五條。

```janet
(if 0 :真 :假)    # => :真
(if "" :真 :假)   # => :真
(if @[] :真 :假)  # => :真
(if nil :真 :假)  # => :假
```

所以 `(if xs ...)` 判斷不了「空不空」，要寫 `(if (empty? xs) ...)`。
細節見 [32](32-條件與模式比對.md)。

### ③ `=` 對可變容器比的是身分，不是內容

Python 的 `==` 一律比內容，`is` 才比身分。Janet 用型別分：

```janet
(= [1 2] [1 2])       # => true    tuple 不可變，比內容
(= @[1 2] @[1 2])     # => false   array 可變，比身分
(deep= @[1 2] @[1 2]) # => true    要比內容用 deep=
```

連帶的：array／table 當不了字典的 key，要用 tuple／struct。

### ④ 整數只有 double

Python 3 的 `int` 是任意精度，Janet 的 `:number` 是 IEEE 754 double，53 bit 以上就開始說謊：

```janet
(= 9007199254740993 9007199254740994)   # => true   兩個字面值是同一個 double
(+ 9007199254740992 1)                  # => 9007199254740992
```

要真 64 bit 得用 `int/s64`（見 [21](21-數字與位元.md)）。另外 `/` 一律是浮點除法，
整數除法叫 `div`，而且**除以零不會拋錯**：

```janet
(/ 7 2)      # => 3.5
(div 7 2)    # => 3
(/ 1 0)      # 不是 ZeroDivisionError，是 inf
```

### ⑤ 字串是 bytes，不是 unicode 字元序列

`length` 數的是 byte，索引取出來的是數字：

```janet
(length "héllo")   # => 6      五個字，六個 byte
(get "abc" 0)      # => 97     不是 "a"
```

要按字元處理中文或 emoji，見 `snippets/utf8-strings.janet`。

### ⑥ `None` 叫 `nil`，而且字典存不進去

把值設成 `nil` 等於刪掉那個 key：

```janet
(length (put @{:a 1} :a nil))    # => 0
(has-key? (put @{:a 1} :a nil) :a)  # => false
```

Python 裡 `d["a"] = None` 之後 `"a" in d` 還是 `True`，這裡不是。
要表示「有這個欄位但沒值」，得自己挑一個哨兵值（例如 `:null`）。

## 這一系列

| 篇 | 講什麼 |
|---|---|
| [46b](46b-Python-資料與推導.md) | 容器、切片、推導、`enumerate`／`zip`／`sorted`／`in` |
| [46c](46c-Python-字典與字串.md) | `dict.get`／`Counter`／`groupby`、f-string、`join`／`split` |
| [46d](46d-Python-函式.md) | lambda、decorator、`partial`、`*args`、generator、`itertools` |
| [46e](46e-Python-錯誤與物件.md) | `try/except/finally`、`with`、class 與 prototype |
| [46f](46f-Python-工具鏈.md) | import、`main`、jpm 對 pip、標準函式庫對照 |

可跑範例（三支，都 exit 0）：

```sh
janet examples/compare-python.janet      # 資料與推導
janet examples/compare-python-fn.janet   # 函式、錯誤
janet examples/compare-python-oop.janet  # 物件、工具鏈
```

下一步：[46b-Python-資料與推導.md](46b-Python-資料與推導.md)。
