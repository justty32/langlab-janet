# 46e · 錯誤處理與「類別」

[← 46 從 Python 過來](46-從-Python-過來.md)

錯誤的完整規則在 [20](20-錯誤處理與資源管理.md)／[20b](20b-資源管理.md)，
prototype 在 [22](22-原型與方法.md)。這裡只放 Python 對照與不一樣的地方。

## try / except / else / finally

| Python | Janet |
|---|---|
| `raise ValueError("x")` | `(error "x")`／`(errorf "bad %d" n)` |
| `try: ... except E as e: ...` | `(try ... ([e] ...))` |
| `except` 拿到 traceback | `(try ... ([e fib] ...))` 第二個參數是 fiber |
| `finally:` | `(defer 收尾 主體)` |
| `else:`（沒出錯才跑） | 放在 `try` 主體的最後一行 |
| 只想知道成不成功 | `(protect expr)` → `[ok? 值]` |
| `assert x, "msg"` | `(assert x "msg")` |

```janet
(try (error :boom) ([e] [:caught e]))   # => (:caught :boom)
(protect (error :boom))                 # => (false :boom)
(protect (+ 1 2))                       # => (true 3)
(try (errorf "bad %d" 7) ([e] e))       # => "bad 7"
```

⚠ Janet 沒有例外**型別**階層，`except ValueError` 那種「按型別挑」不存在。
`try` 一律全接，要分流就自己看 `e` 的內容：

```janet
(defn throw-http [code] (error {:kind :http-error :code code}))
(try (throw-http 404)
  ([e] (if (= :http-error (get e :kind)) [:http (e :code)] (error e))))
# => (:http 404)
```

心法：**自訂 exception ＝ 丟一個 table／struct**，裡面放一個 `:kind` 當標籤。
接不住的就 `(error e)` 重丟，那等於 Python 的 `raise`。

⚠ `defer` 不是 `finally` 的完全對應：它綁在**區塊**上，不是綁在 `try` 上。
順序是主體先跑完（含 catch），才跑 defer。

```janet
(defn run []
  (defer (print "收尾") (try :ok ([e] :err))))
```

### traceback

`try` 的第二個參數是出錯的 fiber，拿它印堆疊：

```janet
(def f (fiber/new (fn [] (error "壞了")) :e))
(resume f)
(fiber/status f)       # => :error
(type (fiber/last-value f))   # => :string
```

`(debug/stacktrace f (fiber/last-value f))` 印到 stderr，等於 `traceback.print_exc()`。
`raise ... from e` 沒有對應語法，要保留原因就自己把舊的錯誤塞進新 table 的欄位裡。

⚠ 有些在 Python 會炸的事，在 Janet 不炸：`(/ 1 0)` 回 `inf`、`(get d :沒有的key)` 回 `nil`
（不是 `KeyError`）。反過來說，你得自己檢查。

## with：一樣是 with

```janet
(with [f (file/open "x.txt" :r)]
  (file/read f :all))
```

`with` 要求那個值有 `:close` 方法（或第三個參數指定收尾函式），
跟 Python 的 `__enter__`／`__exit__` 差在**沒有 `__enter__`**——括號裡那個運算式的結果就直接是 `f`。
自訂 context manager 就是「給那個 table 一個 `:close` 方法」。

## class 對 prototype

Python 的 class 在 Janet 拆成兩件事：**一個放方法的 table（prototype）** ＋ **建構函式**。

```janet
(def Animal @{:speak (fn [self] (string (self :name) " 發出聲音"))})
(def Dog (table/setproto @{:speak (fn [self] (string (self :name) " 汪"))} Animal))
(defn dog [name] (table/setproto @{:name name} Dog))
(:speak (dog "小白"))   # 回 "小白 汪"
```

| Python | Janet |
|---|---|
| `class C:` | `(def C @{...})`，方法放裡面 |
| `def __init__(self, ...)` | 一個普通函式 `(defn c [...] (table/setproto @{...} C))` |
| `self` | 方法的第一個參數，慣例也叫 `self` |
| `obj.m(x)` | `(:m obj x)` |
| `class D(C):` | `(table/setproto D C)` |
| `super().m()` | `((C :m) self)` — 直接從父 table 抓那個函式 |
| `__str__` | 自己定一個 `:describe` 之類的方法，沒有協定 |
| `__eq__` | 沒有；`=` 對 table 一律比身分 |
| `@property` | 沒有；寫成 `(:width obj)` 這種零參數方法 |
| `__getattr__` | prototype 鏈本身就是 fallback |
| `isinstance(x, C)` | 自己沿著 `table/getproto` 往上找 |
| `type(x)` | `(type x)`，但回的是 `:table`，不是你的「類別」 |
| `@dataclass` / `namedtuple` | struct `{:x 1 :y 2}` |

⚠ **`(type obj)` 對所有物件都回 `:table`**。要問「這是不是 Dog」得自己走原型鏈：

```janet
(defn instance-of? [obj proto]
  (var p (table/getproto obj))
  (while (and p (not= p proto)) (set p (table/getproto p)))
  (truthy? p))
```

⚠ `keys`／`pairs`／`each` **不走原型鏈**，只看物件自己的欄位；`get` 才會往上找。
所以 `(keys obj)` 看不到方法，這跟 Python 的 `dir()` 差很多。

### dataclass 用 struct

struct 不可變、按內容比較，剛好對上 `@dataclass(frozen=True)`：

```janet
(= {:x 1 :y 2} {:y 2 :x 1})   # => true
```

沒有欄位名稱檢查，也沒有型別註記——要驗就自己寫一個建構函式加 `assert`。

### duck typing

一樣好用，而且更直白：`(get x :speak)` 有東西就代表它會叫。
`hasattr` 就是 `get`，沒有 `AttributeError` 這回事。

下一步：[46f-Python-工具鏈.md](46f-Python-工具鏈.md)。
