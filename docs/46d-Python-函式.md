# 46d · 函式：lambda、decorator、generator

[← 46 從 Python 過來](46-從-Python-過來.md)

參數的完整規則在 [33 函式參數與閉包](33-函式參數與閉包.md)，這裡只講 Python 對照。

## 參數

| Python | Janet |
|---|---|
| `def f(a, b)` | `(defn f [a b] ...)` |
| `def f(a, b=1)` | `(defn f [a &opt b] (default b 1) ...)` |
| `def f(*args)` | `(defn f [& args] ...)` |
| `def f(**kw)` | `(defn f [&keys kw] ...)` |
| `def f(*, x=1, y=2)` | `(defn f [&named x y] ...)` |
| `lambda x: x*2` | `(fn [x] (* x 2))`／`\|(* $ 2)` |
| `f(*xs)` | `(f ;xs)`／`(apply f xs)` |
| `f(**d)` | `(f ;(kvs d))` |
| `a, b = t` | `(def [a b] t)` |
| `a, *rest = t` | `(def [a & rest] t)` |

```janet
(defn k [a &opt b] (default b 10) [a b])
(k 1)     # => (1 10)
(k 1 2)   # => (1 2)
```

`&keys` 把關鍵字參數收成一個 struct，`&named` 則是各自綁成變數：

```janet
(defn h [&keys kw] kw)
(h :x 1 :y 2)   # => {:x 1 :y 2}
```

⚠ **參數個數是編譯期檢查的**，`try` 攔不到，跟 Python 的 `TypeError` 完全不同性質。見 33。

⚠ 沒有 `*` 跟 `**` 兩種 splat，只有一個 `;`。要攤開字典就先 `(kvs d)` 把它壓成
`[k v k v ...]` 再 splice。可抄的版本在 `snippets/apply-splice.janet`。

### 預設參數的可變陷阱：Janet 沒有

Python 的 `def f(x, acc=[])` 那個經典坑，在 Janet 不存在——
`(default b @[])` 是**每次呼叫**才求值：

```janet
(defn push-it [x &opt acc] (default acc @[]) (array/push acc x) acc)
(push-it 1)   # => @[1]
(push-it 2)   # => @[2]
```

⚠ 但把同一個 array 掛在**頂層** `def` 上再拿來當預設值，就一樣會共用——
坑還在，只是搬了家。

## 高階函式

| Python | Janet |
|---|---|
| `map(f, xs)` | `(map f xs)` — 回 array，不是 iterator |
| `filter(p, xs)` | `(filter p xs)` |
| `functools.reduce(f, xs, 0)` | `(reduce f 0 xs)` |
| `functools.reduce(f, xs)` | `(reduce2 f xs)` |
| `itertools.accumulate` | `(accumulate f 0 xs)` |
| `functools.partial(f, 10)` | `(partial f 10)` |
| `lambda x: g(h(x))` | `(comp g h)` |

```janet
((partial + 10) 5)          # => 15
((comp inc inc) 1)          # => 3
(accumulate + 0 [1 2 3])    # => @[1 3 6]
((juxt inc dec) 5)          # => (6 4)
```

`|` 是最短的 lambda 寫法：`$` 是第一個參數，`$0` `$1` 是第 n 個。

⚠ `(function? print)` 是 `false`——內建的是 `:cfunction`，自己寫的才是 `:function`。
要判斷「能不能呼叫」得兩個都測，見 [38](38-型別全表.md)。

## decorator

Python 的 `@decorator` 就是 `f = decorator(f)`。Janet 沒有這個語法糖，
但因為函式是值，直接包一層就好：

```janet
(defn log-calls [f]
  (fn [& args] (printf "呼叫 %j" args) (f ;args)))
(def add* (log-calls +))
(add* 1 2)   # 先印「呼叫 (1 2)」，再回 3
```

想要 `@` 那種寫在定義上面的感覺，就寫個巨集（見 [08](08-巨集-macro.md)）：

```janet
(defmacro defn-logged [name args & body]
  ~(def ,name (log-calls (fn ,name ,args ,;body))))
```

巨集比 Python 的 decorator 強的地方是它拿得到**原始語法**，
所以能做「印出參數名稱」這種 decorator 做不到的事。

## generator 與 yield

Python 的 generator function 對應 fiber（見 [09](09-fiber.md)）：

```janet
(def g (fiber/new (fn [] (each x [1 2 3] (yield (* x x))))))
(resume g)   # => 1
(resume g)   # => 4
```

`resume` 就是 `next()`，跑完之後 `(fiber/status g)` 變 `:dead` 而不是丟 `StopIteration`。
只是要做 generator expression 的話用 `generate` 更短，而且能直接餵給 `:in`：

```janet
(seq [x :in (generate [i :range [0 3]] i)] x)   # => @[0 1 2]
```

⚠ fiber 沒有 `send()`：`(resume f v)` 傳進去的值是 `yield` 的回傳值，方向跟 Python 一樣，
但沒有 `throw()` / `close()` 那套協定。

## itertools

| Python | Janet |
|---|---|
| `islice(xs, 2)` | `(take 2 xs)` |
| `islice(xs, 2, None)` | `(drop 2 xs)` |
| `takewhile` / `dropwhile` | `(take-while p xs)` / `(drop-while p xs)` |
| `chain.from_iterable` | `(mapcat identity xs)` |
| `zip(*)` | `(map tuple a b)` |
| `range(1, 10, 3)` | `(range 1 10 3)` |
| `chunked`（第三方） | `(partition 2 xs)` |
| `groupby` | `(partition-by f xs)`，見 [46c](46c-Python-字典與字串.md) |
| `count` / `cycle` / `repeat`（無限） | 沒有，用 `generate` 自己寫 |
| `product` / `permutations` | 沒有內建，`spork/math` 有組合數學 |

```janet
(take 2 [1 2 3])           # => (1 2)
(drop-while even? [2 4 1]) # => (1)
(range 1 10 3)             # => @[1 4 7]
(mapcat |[$ $] [1 2])      # => @[1 1 2 2]
```

⚠ 切割類（`take`／`drop`／`take-while`）回的是 **tuple**，`map`／`filter` 回 array。
這個不一致很容易在寫測試時對不起來，見 [25](25-序列工具.md)。

下一步：[46e-Python-錯誤與物件.md](46e-Python-錯誤與物件.md)。
