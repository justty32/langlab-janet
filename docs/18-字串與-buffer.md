# 18 · 字串與 buffer

Janet 有兩種「文字」：**string 不可變、buffer 可變**。對到 C++ 大概是
`std::string_view`（唯讀、可共享）對 `std::string`（可就地增長）。

```janet
"abc"      # string，不可變
@"abc"     # buffer，可變（前面加 @，跟 array/table 一樣的規則）
```

兩者在多數函式裡可以混用（都算 `bytes` 型別），但**只有 buffer 能改內容**。

## 什麼時候用哪個

| 情境 | 用 |
|------|-----|
| 一般字面值、當 key、當回傳值 | string |
| 迴圈裡一段一段拼出來 | buffer（省掉大量中間字串） |
| 收 I/O 讀進來的資料 | buffer（`file/read`、`net/read` 都回 buffer） |

```janet
(def b @"")
(loop [i :range [0 3]]
  (buffer/push-string b (string i ",")))
(pp b)              # => @"0,1,2,"
(string b)          # => "0,1,2,"   轉回不可變 string
```

⚠ **buffer 拿去當 table 的 key 會出事**——它可變，改了之後就查不到了。當 key 前先 `(string b)`。
這也是 spork/http 回傳 buffer 時最常見的坑，見 [17](17-用-spork-http-打-api.md)。

## 常用 string/ 函式

```janet
(string/split "," "a,b,c")        # => @["a" "b" "c"]   ⚠ 分隔符在「前面」
(string/join @["a" "b"] "-")      # => "a-b"
(string/find "b" "abc")           # => 1（找不到回 nil）
(string/replace "a" "X" "banana")     # => "bXnana"（只換第一個）
(string/replace-all "a" "X" "banana") # => "bXnXnX"
(string/trim "  hi \n")           # => "hi"
(string/slice "hello" 1 3)        # => "el"（含頭不含尾，負數從尾算）
(string/repeat "ab" 3)            # => "ababab"
(string/ascii-upper "abc")        # => "ABC"
(string/has-prefix? "he" "hello") # => true
(length "hello")                  # => 5
```

⚠ **參數順序**：`string/split`、`string/find`、`string/replace` 都是**「要找的東西放前面，
被找的字串放最後」**。跟大部分語言相反，寫錯不會報錯、只會靜默給你怪結果。

心法：Janet 的字串函式一律把「被操作的資料」放最後一個參數，就是為了配合 `->>`：

```janet
(->> "  a,b,c  " string/trim (string/split ",") (map string/ascii-upper))
# => @["A" "B" "C"]
```

## 組字串：string vs 格式化

```janet
(string "id=" 42 " ok=" true)     # => "id=42 ok=true"   什麼都能接
(string/format "%s scored %.2f" "Al" 3.14159)   # => "Al scored 3.14"
```

`+` **不會**串字串（會直接錯），只有 `string` 和 `string/format` 這兩條路。

### 格式動詞速查

| 動詞 | 意思 |
|------|------|
| `%s` | 只吃字串類（string / buffer / symbol / keyword） |
| `%d` `%f` `%.2f` `%x` | 整數／浮點／十六進位，跟 C 的 printf 一樣 |
| `%q` | **Janet 可讀表示法**——印陣列 / table 內容就用這個 |
| `%p` | pretty，內容太長會自動折行縮排 |
| `%j` | 單行 Janet 表示法（⚠ 不是 JSON！） |
| `%v` | 像 `print` 那樣印（容器只會得到位址） |
| `%%` | 一個百分號 |

```janet
(string/format "%s" @[1 2])   # ⚠ 直接報錯：expected string...got <array>
(string/format "%v" @[1 2])   # => "<array 0x...>" 位址，不是你要的
(string/format "%q" @[1 2])   # => "@[1 2]"  ← 要這個
```

真 JSON 只有 `(json/encode x)` 一條路，見 [03](03-json.md)。

## 印出來：print / prin / printf 的差別

| 函式 | 格式化 | 自帶換行 |
|------|--------|----------|
| `print` | ✗ | ✓ |
| `prin` | ✗ | ✗ |
| `printf` | ✓ | ✓ |
| `prinf` | ✓ | ✗ |
| `pp` | 自動用 `%p` | ✓ |

規則好記：**有 `t` 結尾（prin**t**）就有換行**。寫 `(printf "%d\n" x)` 會多一行空白，
這在 Windows 上還會變成 `\r\n\r\n`，很容易讓輸出比對的測試莫名其妙失敗。

前面加 `x` 的版本（`xprint`／`xprintf`）第一個參數是輸出目標，可以寫進檔案或 stderr：

```janet
(xprint stderr "警告：檔案不存在")
```

## 字串是 byte 陣列，不是字元陣列

這點跟 C++ 的 `std::string` 一模一樣：**索引與 `length` 都是以 byte 計**。

```janet
(length "中文")     # => 6，不是 2（UTF-8 每字 3 bytes）
("hello" 0)         # => 104，是 byte 值（h 的 ASCII），不是 "h"
(string/slice "hello" 0 1)   # => "h"，要取「一個字」得用 slice
(string/bytes "hi") # => (104 105)
(string/from-bytes 104 105)  # => "hi"
```

⚠ 對非 ASCII 字串做 `string/slice`／索引，切在半個字中間就會產生壞掉的 byte 序列。
要正確處理 UTF-8 請走 PEG（見 [14](14-peg.md)）或參考
[`snippets/utf8-strings.janet`](../snippets/utf8-strings.janet)。

## 字串轉數字、數字轉字串

```janet
(scan-number "42")        # => 42（不是數字回 nil，不會拋錯）
(scan-number "0x1f")      # => 31
(scan-number "abc")       # => nil   ← 用這個判斷「是不是合法數字」
(string 42)               # => "42"
(parse "[1 2]")           # => [1 2]   把 Janet 原始碼字串變資料
```

`scan-number` 就是安全版的 `std::stoi`——不會拋例外，失敗回 `nil`，很適合直接接 `if-let`。

## 其它「名字」型別

字串、buffer、symbol、keyword 是四種相關但不同的型別，跨型別的 `=` 一律 false。
`("abc" = :abc)` 這種坑請直接看 [13-symbol-keyword-字串.md](13-symbol-keyword-字串.md)。

下一步：[19-檔案與檔案系統.md](19-檔案與檔案系統.md)。
