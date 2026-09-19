# 44b · 從 Lua 過來：閉包、metatable、pcall、coroutine、require

[← 44 入口](44-從-Lua-過來.md)

## 閉包與 upvalue：一樣，但要改就得寫 var

Lua 的 upvalue 直接 `n = n + 1`；Janet 的外層變數要宣告成 `var` 才能 `set`，其餘行為相同：

```janet
(var n 0)
(defn inc! [] (++ n))
(inc!) (inc!)
n   # => 2
```

⚠ Lua 忘了寫 `local` 會變全域；Janet 沒有這個坑，對沒宣告過的名字 `set` 是**編譯錯**
`unknown symbol undefined-name`。

## metatable → prototype

Lua 用 `setmetatable(obj, {__index = Class})` 做物件；Janet 的 table 天生有一個 prototype 欄位，
`table/setproto` 就是 `__index` 那條路（[22](22-原型與方法.md)）：

```janet
(def Animal @{:speak (fn [self] (string (self :name) " 叫"))})
(def d (table/setproto @{:name "狗"} Animal))
(:speak d)                       # 呼叫方法 → "狗 叫"；等於 Lua 的 d:speak()
(table/rawget d :speak)          # => nil    自己身上沒有，跟 rawget 一樣
(= (table/getproto d) Animal)    # => true   getmetatable(d).__index
```

`(:speak d)` 是 Janet 的 `d:speak()`：查 `:speak`、找到就以 `d` 當第一個參數呼叫。

⚠ 只有 `__index` 這一條有對應物。**沒有 `__add`、`__eq`、`__tostring`、`__call`**：

```janet
(+ @{:v 1} @{:v 2})   # 錯：could not find method :+ for <table …> or :r+ for <table …>
(string @{:a 1})      # => "<table 0x…>"  沒有 __tostring；要自訂就自己寫 (defn show …)
```

（`:+`／`:r+` 那條訊息看起來像有運算子重載，但那是給 C 寫的 abstract type 用的，table 掛不上。）

## pcall → protect，error 一樣能丟任何值

```janet
(protect (error "boom"))   # => (false "boom")   形狀跟 pcall 一模一樣：(ok? 值)
(protect (+ 1 1))          # => (true 2)
(def [ok v] (protect (error "boom")))
ok                         # => false
```

要 `try`／`catch` 的寫法也有：`(try body ([e] 處理))`；`error` 跟 Lua 一樣可以丟 table，
`catch` 端拿到原物件（[20](20-錯誤處理與資源管理.md)）：

```janet
(try (error {:code 42 :msg "x"}) ([e] (e :code)))   # => 42
```

⚠ Lua 的 `error("msg")` 會自動在前面加上 `file:line:`；Janet 不會，訊息就是你給的那個值。
位置在 fiber 的 stacktrace 裡，`([e f] …)` 的第二個參數就是它（[34](34-讀錯誤訊息.md)）。

## coroutine → fiber

| Lua | Janet |
|-----|-------|
| `coroutine.create(f)` | `(fiber/new f)`；或 `(coro body…)` 直接包 |
| `coroutine.resume(co, v)` | `(resume co v)`，回傳的是 yield 出來的值本身，不帶 `true` |
| `coroutine.yield(v)` | `(yield v)` |
| `coroutine.status(co)` | `(fiber/status co)`：`:pending`／`:dead`（Lua 的 `suspended`／`dead`） |
| `coroutine.wrap(f)` 當迭代器 | 直接 `(each x fiber …)`，fiber 本身就能走 |

```janet
(def co (coro (yield 1) (yield 2) 3))
[(resume co) (fiber/status co) (resume co) (resume co) (fiber/status co)]   # => (1 :pending 2 3 :dead)
(resume co)     # 錯：cannot resume fiber with status :dead   跟 Lua 一樣
(seq [x :in (coro (yield :a) (yield :b))] x)   # => @[:a :b]
```

fiber 比 coroutine 多一件事：它同時是 `try` 與 `ev` 的底層（[09](09-fiber.md)）。

## require → import

| Lua | Janet | 說明 |
|-----|-------|------|
| `local p = require "spork.path"` | `(import spork/path :as p)` | 之後用 `p/join`，斜線不是點 |
| `require` 回傳模組 table | `(require "spork/path")` 也有，回 env table | 日常用 `import`，它幫你綁名字 |
| `package.path` | `(dyn *module-paths*)` | [05e](05e-import-與模組路徑.md) |
| 在函式裡 `require` | ⚠ **不行**，`import` 只能放頂層 | 放函式裡會編譯錯 `unknown symbol p/join` |

```janet
(import spork/path :as p)
(p/join "a" "b")   # => "a/b"
```

## ipairs／pairs → each／eachp／eachk

```janet
(def r @[])
(eachp [i v] @[:a :b] (array/push r [i v]))
r   # => @[(0 :a) (1 :b)]    ipairs，索引從 0
(def r2 @[])
(eachp [k v] @{:x 1} (array/push r2 [k v]))
r2  # => @[(:x 1)]           pairs
(keys @{:b 1 :a 2 :c 3})     # => @[:b :a :c]   ⚠ 順序不保證，跟 Lua 的 pairs 一樣
```

`each` 只走值、`eachk` 只走 key；對 table 用 `each` 拿到的是**值**，不是 key。
`table.insert`／`table.remove`／`table.concat`／`table.sort` 對到 `array/push`／`array/remove`／
`string/join`／`sort`（[25](25-序列工具.md)、[36](36-排序與比較.md)）。

## 可跑範例

```sh
janet examples/compare-lua.janet
```

下一步：[45 從 Go 過來](45-從-Go-過來.md)，或 [09 fiber](09-fiber.md) 把 coroutine 那套完整走一遍。
