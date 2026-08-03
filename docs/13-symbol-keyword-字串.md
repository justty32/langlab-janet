# 13 · symbol / keyword / 字串 互轉

Janet 有**四種**「一串位元組」的型別，長得像但用途不同：

| 型別 | 字面 | 可變 | 求值時 | 幹嘛用的 |
|------|------|------|--------|----------|
| **string** | `"abc"` | ✗ | 就是自己 | 資料、文字 |
| **buffer** | `@"abc"` | ✓ | 就是自己 | 可變字串（拼接、IO 緩衝） |
| **keyword** | `:abc` | ✗ | **就是自己** | 當標籤：table 的 key、選項名、狀態 |
| **symbol** | `abc` | ✗ | **會被查表求值** | 程式碼裡的名字（變數 / 函式名） |

關鍵差別只有一條：**`:abc` 求值成 `:abc` 自己；`abc` 求值成「abc 這個綁定的值」。**
所以要「一個純標籤」就用 keyword，要「指涉某個名字」才用 symbol（多半出現在巨集裡）。

---

## 字串 → 符號

```janet
(keyword "some_symbol")   # => :some_symbol
(symbol  "some_symbol")   # => some_symbol
```

`keyword` / `symbol` 都吃**多個參數並串接**，任何型別都會先轉成字串：

```janet
(keyword "a-" 1 :b 'c)    # => :a-1bc
(symbol "my" "-" "fn")    # => my-fn
(keyword (buffer "buf"))  # => :buf
(keyword)                 # => :        （空 keyword，合法但沒用）
```

## 符號 → 字串

```janet
(string :some_symbol)     # => "some_symbol"   ★ 冒號不會留著
(string 'some_symbol)     # => "some_symbol"
```

要**帶冒號**的可讀表示，用 `%q`（Janet 表示法）而不是 `%s`：

```janet
(string/format "%q" :abc)   # => ":abc"
(string/format "%s" :abc)   # => "abc"
(string/format "%q" 'abc)   # => "abc"    symbol 本來就沒前綴
```

## 互轉

```janet
(keyword 'abc)   # symbol  → keyword => :abc
(symbol :abc)    # keyword → symbol  => abc
```

四種型別兩兩之間都通，統一走「先變字串再包回去」，所以只要記 `string` / `buffer` /
`keyword` / `symbol` 四個建構子就好。

---

## ★ 最容易踩的坑：跨型別 `=` 一律 false

```janet
(= "abc" :abc)              # => false   ← 不是同型別
(= (string :abc) "abc")     # => true
(= :abc (keyword "abc"))    # => true    ← 同型別、同內容就相等（keyword 有 intern）
```

JSON 解回來 key 是**字串**，自己寫的 Janet 用 keyword，兩邊一比就 false——這就是
[03-json.md](03-json.md) 要你 `(json/decode s true)` 的原因。

## 坑二：造得出來、讀不回去的 keyword

`keyword` 不檢查內容，什麼字元都給你包：

```janet
(pp (keyword "has space"))   # => :has space   ← 印得出來，但貼回原始碼無法 parse
```

從外部資料（JSON key、CSV 欄名、使用者輸入）造 keyword 前先正規化：

```janet
(keyword (string/replace-all " " "-" raw))
```

---

## 常見用法

### 把字串 key 的 table 轉成 keyword key

```janet
(struct ;(mapcat (fn [[k v]] [(keyword k) v]) (pairs {"a" 1 "b" 2})))
# => {:a 1 :b 2}
```

（JSON 專用的話直接 `(json/decode s true)` 就好，不用自己轉。）

### 用執行期算出來的名字取值

```janet
(def t @{:a 1})
(t (keyword "a"))          # => 1
(in {:a 1} (keyword "a"))  # => 1
```

### 用執行期算出來的名字取「綁定」

```janet
(def x 5)
(eval (symbol "x"))                    # => 5
(get (curenv) (symbol "x"))            # => @{:value 5 …}  連 meta 一起
((eval (symbol "string/trim")) "  x  ") # => "x"  動態取函式來呼叫
```

> `eval` 會編譯執行任意程式碼。名字若來自外部輸入，用 `(get (curenv) (symbol s))`
> 取綁定、再自己 `:value`，比 `eval` 安全得多。env 的細節見 [12](12-env-環境與動態變數.md)。

### 型別判斷

```janet
(keyword? :k)    # => true
(symbol? 'k)     # => true
(string? "s")    # => true
(buffer? @"b")   # => true
(bytes? :k)      # => true   ★ 四種都算 bytes
(map type [:k 'sym "s" @"b"])   # => @[:keyword :symbol :string :buffer]
```

要寫「string 或 keyword 都收」的函式，先 `(string x)` 正規化再處理最省事。

---

## 速查

| 想幹嘛 | 怎麼寫 | 結果 |
|--------|--------|------|
| 字串 → `:符號` | `(keyword "abc")` | `:abc` |
| 字串 → 程式名 | `(symbol "abc")` | `abc` |
| `:符號` → 字串（無冒號） | `(string :abc)` | `"abc"` |
| `:符號` → 字串（帶冒號） | `(string/format "%q" :abc)` | `":abc"` |
| keyword ↔ symbol | `(symbol :abc)` / `(keyword 'abc)` | `abc` / `:abc` |
| 串接著造 | `(keyword "a-" 1 :b)` | `:a-1b` |
| 比較 | 先轉同型別再 `=` | 跨型別永遠 false |
| 名字查值 | `(eval (symbol s))` 或 `((get (curenv) (symbol s)) :value)` | |

回目錄：[docs/README.md](README.md)。
