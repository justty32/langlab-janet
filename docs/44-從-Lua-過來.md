# 44 · 從 Lua 過來：逐條對照

[01b](01b-給-C++-開發者.md) 是給 C++ 的概念表；這篇是給 **Lua 使用者**的：兩個語言都小、都動態、都有協程，
所以九成是「換個名字」，剩下一成是真的不一樣的地方，用 ⚠ 標。分兩支：

- **本篇**：容器、索引從 0 起、`nil` 與 `false`、`#`、多重回傳、`...`、字串、算術
- [44b](44b-從-Lua-閉包-metatable-協程.md)：閉包、metatable 對 prototype、`pcall`、coroutine、`require`、`ipairs`／`pairs`

`return`／`break`／`goto continue` 的對照在 [01d](01d-提早離開-return-break-continue.md)。

## table 就是一切 → 四種容器

Lua 一個 `table` 包辦陣列與字典；Janet 拆成四個，還分可變／不可變（[02](02-資料結構.md)）：

| Lua | Janet | 說明 |
|-----|-------|------|
| `{1, 2, 3}` | `@[1 2 3]` array | 可變 |
| `{1, 2, 3}` 不打算改 | `[1 2 3]` tuple | 不可變，可以當 table 的 key |
| `{a = 1}` | `@{:a 1}` table | 可變 |
| `{a = 1}` 不打算改 | `{:a 1}` struct | 不可變 |
| `t.a`／`t["a"]` | `(get t :a)`／`(t :a)` | key 通常用 keyword `:a` |
| `t.a = 2` | `(put t :a 2)` | |
| `t[1]`（數字 key） | `(get t 1)` | table 一樣能混用 key |

```janet
(def t @{:a 1 1 :one "s" 2})
[(get t 1) (get t :a) (get t "s") (length t)]   # => (:one 1 2 3)
```

## ⚠ 索引從 0 開始

```janet
(get [10 20 30] 0)    # => 10     Lua 的 t[1]
(get [10 20 30] 3)    # => nil    越界給 nil，跟 Lua 一樣
(last [10 20 30])     # => 30     Lua 的 t[#t]
(get [10 20 30] -1)   # => nil    ⚠ 負索引不是從尾數，就是拿不到
(slice [10 20 30] -2) # => (30)   slice 的負數才是從尾數（跟 s:sub(-2) 一樣）
(in [10 20 30] -1)    # 錯：expected integer key for tuple in range [0, 3), got -1
```

`get` 拿不到給 `nil`；`in` 拿不到報錯，要「一定要有」時用它。

## nil 與 false：跟 Lua 一樣，只有這兩個是假

`0`、`""`、空 table 都是真，這點 Lua 使用者不用調適。
`(put t :a nil)` 也跟 Lua 一樣是**刪掉那個 key**。差別在陣列：

```janet
(put @{:a 1 :b 2} :a nil)   # => @{:b 2}
(length @[1 nil 3])         # => 3         ⚠ array 可以放 nil，長度照算；Lua 的 #t 會亂掉
```

## `#t` → `length`

```janet
(length @{:a 1 :b 2})   # => 2    ⚠ Lua 的 # 對 hash 部分不算；Janet 算所有 key
(length "abc")          # => 3
(length [1 2])          # => 2
```

## 多重回傳 → tuple ＋ 解構

Lua 的 `return q, r` 是真的多個值；Janet 回一個 tuple，接的時候拆開（[01c](01c-解構與執行緒巨集.md)）：

```janet
(defn divmod [a b] [(div a b) (% a b)])
(def [q r] (divmod 7 2))
[q r]                   # => (3 1)
(def [a b c] [1 2])
c                       # => nil    多的變數是 nil，跟 Lua 一樣
```

## `...` → `& rest`

```janet
(defn f [& rest] [(length rest) rest])
(f)          # => (0 ())      select('#', ...) 就是 (length rest)
(f 1 2)      # => (2 (1 2))   {...} 就是 rest 本身，已經是 tuple
(defn g [a b c] [a b c])
(g ;[1 2 3]) # => (1 2 3)     table.unpack(t) 就是 ;t
```

## 字串：`s:sub` → `string/slice`，還有幾個名字

| Lua | Janet | 實測 |
|-----|-------|------|
| `s:sub(2, 3)` | `(string/slice s 1 3)` | ⚠ 0-based、**半開**：`"hello"` → `"el"` |
| `s:sub(-3)` | `(string/slice s -3)` | `"lo"`，負數一樣從尾數 |
| `#s` | `(length s)` | byte 數，兩邊一樣 |
| `s:byte(1)` | `(get s 0)` | `97` |
| `string.char(97)` | `(string/from-bytes 97)` | `"a"` |
| `s:upper()` | `(string/ascii-upper s)` | 只管 ASCII |
| `string.rep(s, 2)` | `(string/repeat s 2)` | |
| `s:find("l", 1, true)` | `(string/find "l" s)` | ⚠ **參數順序反過來**（找什麼在前），回 0-based 的 `2`，沒有給 `nil` |
| `s:gsub("l", "L")` | `(string/replace-all "l" "L" s)` | 純文字取代，不是 pattern |
| Lua pattern | PEG | 見 [14](14-peg.md)，威力大很多 |

### 串接與轉換

| Lua | Janet | 實測 |
|-----|-------|------|
| `a .. b` | `(string a b)` | 什麼型別都吃 |
| `"1" + 1` → `2` | `(+ "1" 1)` | ⚠ **報錯** `could not find method :+ for "1"`，沒有自動轉型 |
| `tonumber(s)` | `(scan-number s)` | 失敗給 `nil`，一樣 |
| `tostring(x)` | `(string x)` | `(string nil)` 是 `""` 不是 `"nil"` |
| `string.format` | `string/format` | 動詞同一套（`%d %s %5.2f %q`） |

```janet
(string/slice "hello" 1 3)     # => "el"
(string/find "l" "hello")      # => 2
(string "a" 1 2.5)             # => "a12.5"
(scan-number "abc")            # => nil
(string/format "%5.2f|%q" 3.14159 "a\"b")   # => " 3.14|\"a\\\"b\""
```

## 算術：`//` 一樣，`%` 不一樣

```janet
(div -7 2)         # => -4    Lua 5.3 的 -7 // 2，一樣是往下取整
(mod -7 2)         # => 1     Lua 的 -7 % 2 是 1，對到 mod
(% -7 2)           # => -1    ⚠ Janet 的 % 是 C 那種，跟被除數同號
(math/pow 2 10)    # => 1024  Lua 的 2 ^ 10
(not= 1 2)         # => true  Lua 的 ~=
(= 1 1.0)          # => true  沒有 5.3 的 integer／float 之分，全部 double（21）
```

下一步：[44b 閉包、metatable、協程](44b-從-Lua-閉包-metatable-協程.md)。
