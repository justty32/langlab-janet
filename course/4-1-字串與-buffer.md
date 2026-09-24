# 4-1 · 字串與 buffer

這課講 Janet 怎麼放文字。你會學到兩種「文字」：改不動的字串、改得動的 buffer；還有一件第一天就會撞到的事：`+` 不能拿來接字串。

## 這是什麼、為什麼

在 Python 或 JS 裡，字串只有一種。Janet 分成兩種：

- string（字串）：寫成 `"abc"`，做出來之後內容就不能改。
- buffer（可以一直往後加的文字容器）：寫成 `@"abc"`，前面多一個 `@`，能追加、能清空。

「前面多一個 `@` 就是可變版」跟 3-1 講的 array 是 `@[...]`、table 是 `@{...}` 是同一條規則。

為什麼要分兩種？因為「改不動」在很多地方是優點：字串可以放心當 table 的鍵、放心交給別的函式，不怕誰偷偷改了。真的要一段一段拼文字時（迴圈裡累積輸出、讀檔案讀進來的資料），才用 buffer，省掉每拼一次就造一個新字串的浪費。

## 動手

### 字串改不動

```janet
(def s "abc")
(type s)   # => :string
(protect (put s 0 120))   # => (false "expected array, table or buffer, got \"abc\"")
```

`put` 是 3-2 教的「改容器裡某一格」。對字串做會直接報錯：它不在可以改的名單裡。

想要「改過的字串」，做法是造一個新的：

```janet
(def s "abc")
(def s2 (string s "def"))   # => "abcdef"
(string s)   # => "abc"
```

`string` 這個函式把所有參數接成一個新字串，原本的 `s` 完全沒動。

### buffer 改得動

```janet
(def b @"abc")
(type b)   # => :buffer
(buffer/push-string b "def")   # => @"abcdef"
(string b)   # => "abcdef"
```

`buffer/push-string` 把東西接到 buffer 尾巴，而且是就地改：第二次看 `b`，內容已經變了。這跟上面 `string` 的行為剛好相反。

常用的還有這幾個：

```janet
(def b @"x")
(buffer/push b "y" "z")   # => @"xyz"
(buffer/clear b)   # => @""
(buffer "a" 1 :k)   # => @"a1k"
```

`buffer/push` 一次可以塞好幾個；`buffer/clear` 清空；`buffer` 函式跟 `string` 一樣什麼都能接，只是做出來的是 buffer。

### 兩邊互轉

```janet
(string @"abc")   # => "abc"
(buffer "abc")   # => @"abc"
```

下一課那些 `string/` 開頭的函式兩種都收，回傳的一律是字串。所以平常的習慣是：拼的時候用 buffer，拼完 `(string b)` 轉成字串交出去。

### 迴圈裡拼文字

```janet
(def out @"")
(each i [1 2 3]
  (buffer/push out (string i) ","))
(string out)   # => "1,2,3,"
```

`each` 是 5-2 才細講的迴圈，這裡先看：每繞一圈就把數字跟逗號推進 `out`，最後轉成字串。這正是 buffer 存在的理由。

### `+` 不接字串

```janet
(protect (+ "a" "b"))   # => (false "could not find method :+ for \"a\" or :r+ for \"b\"")
(string "a" "b")   # => "ab"
(string "id=" 42 " ok=" true)   # => "id=42 ok=true"
```

`+` 在 Janet 只做數字加法。要把字串接起來，用 `string`；它什麼型別都收，數字、true、keyword 都會自動變成文字，nil 會變成空字串。

要排版的（補零、小數位數）用 `string/format`，2-2 已經見過：

```janet
(string/format "%s scored %.2f" "Al" 3.14159)   # => "Al scored 3.14"
(string/format "%05d" 42)   # => "00042"
(protect (string/format "%s" 42))   # => (false "bad slot #1, expected string, symbol, keyword or buffer, got 42")
```

`%s` 只吃文字類（string、buffer、keyword、symbol），塞數字給它就錯。數字用 `%d`（整數）或 `%.2f`（小數），懶得分就用 `%q`，什麼都印得出來。

## 你會踩的坑

⚠ 字串跟 buffer 內容一樣，`=` 卻說不相等。
你會以為 `(= "abc" @"abc")` 是 true。其實是 false。因為 3-3 講過 `=` 對可變的東西比的是身分不是內容，buffer 是可變的，就算跟字串長得一樣也不算同一個。要比內容，先 `(string b)` 再比。

⚠ buffer 當 table 的鍵會查不到。
你會以為 `(put t @"key" 1)` 之後 `(get t "key")` 拿得到 1。其實拿到 nil。因為鍵的比對走的也是 `=`，buffer 只跟它自己那一個相等，連另一個內容相同的 buffer 都查不到。從檔案或網路讀進來的資料都是 buffer，要當鍵之前先 `(string ...)`。

⚠ `%d` 不接小數。
你會以為 `(string/format "%d" 3.5)` 會四捨五入或截掉。其實直接報錯 `can not convert number 3.5 to 64 bit signed integer`。因為 `%d` 要的是整數，Janet 不替你決定怎麼捨。用 `%.0f` 或 `%q`。

## 小練習

1. 用 `string` 把 `"總分 "` 跟 `90` 接起來印出來。
2. 從 `@""` 開始，用 `each` 走過 `["甲" "乙" "丙"]`，把每個字後面加 `"、"` 推進 buffer，最後轉成字串印出。
3. 寫一行 `string/format`，把 `3.14159` 印成 `圓周率約 3.14`。

## 想更深

- [docs/18 字串與 buffer](../docs/18-字串與-buffer.md)：多講了 print／prin／printf 的差別表、`%p`／`%v` 等格式動詞、字串轉數字。
- [docs/13 symbol、keyword、字串](../docs/13-symbol-keyword-字串.md)：四種「名字」型別為什麼互不相等。

下一課：[4-2 · 字串常用招式](4-2-字串常用招式.md)
