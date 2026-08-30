# 29 · spork 資料、編碼與文字

這篇把六個「**處理資料進出**」的 spork 模組串起來講：驗證、比對、編碼、壓縮、比對字串、日期。
這裡只講**觀念與坑**；各模組的實測筆記在 [`reference/spork/`](../reference/spork/README.md)，
完整 API 查[官方 repo](https://github.com/janet-lang/spork)。

## 一、schema：宣告資料該長什麼樣

設定檔、API 回應、使用者輸入——你需要在用它之前先確認形狀對不對。

```janet
(import spork/schema)

(def 使用者? (schema/predicate (props :name :string :age :number)))
(使用者? {:name "Alice" :age 30})    # => true
(使用者? {:name "Alice" :age "30"})  # => false   age 型別錯
```

`predicate` 回**真假**，`validator` 回同樣的檢查但**失敗會拋錯並說明原因**：

```janet
((schema/validator :number) "abc")
# error: failed clause :number, expected value of type number, got "abc"
```

積木：`:keyword` 比對型別、`(props k v …)` 逐欄位、`(enum …)` 列舉、`(or …)` `(and …)`、
`(length n)`、`(pred f)` 自訂判斷。⚠ **兩個一定會踩的坑**：

1. **裸 struct 不是「逐欄位驗證」**。`(schema/predicate {:name :string})` 不會檢查欄位，
   它把整包拿去跟輸入做 `=` 比較，幾乎必然回 `false`。要驗欄位**一定要用 `(props …)`**。
2. **`predicate`／`validator` 是巨集，`make-predicate`／`make-validator` 是函式。**
   用函式版時引數會**先被求值**，而 `or`、`and` 剛好是 Janet 的特殊形式——
   `(schema/make-predicate (or :number :nil))` 裡的 `(or :number :nil)` 會先求值成 `:number`，
   schema 悄悄變成「只認數字」，**完全不會報錯**，只是驗證邏輯默默錯了。
   用函式版就記得 quote：`(schema/make-predicate '(or :number :nil))`。

## 二、data/diff：兩份資料差在哪

```janet
(import spork/data)
(data/diff {:a 1 :b 2} {:a 1 :b 3})   # => @[@{:b 2} @{:b 3} @{:a 1}]
```

回傳固定是 **`[只在左邊 只在右邊 兩邊相同]`** 三格。寫測試比對「預期 vs 實際」時比
`deep=` 只給你 true/false 有用得多——它直接告訴你差在哪個 key。

## 三、base64 / crc / zip：編碼與壓縮

這三個加上 `utf8` 都是**原生模組**（`.so`），Windows 上有裝不起來的坑（見 [27](27-spork-全覽.md)）。

```janet
(import spork/base64)
(base64/encode "hello")      # => "aGVsbG8="
(base64/decode "aGVsbG8=")   # => "hello"
```

**base64 是幹嘛的**：把任意二進位資料變成只有 ASCII 的字串，好塞進 JSON、URL、HTTP header
這些只吃文字的地方，代價是**變大約 1/3**。本 repo 的 `modules/llm-http/media.janet`
就是用它把圖片轉成 data URI。

```janet
(import spork/crc)
(def crc32 (crc/named-variant :crc32))
(crc32 "hello")   # => 907060870
```

**CRC 是幹嘛的**：算一個短短的校驗碼，檢查資料在傳輸或存放中有沒有壞掉。
⚠ 它**不是加密也不是雜湊**，別拿來做安全用途（改資料的人可以把 CRC 一起改對）。
而且 `named-variant` 的名字**只有幾個真的實作了**，其餘一律丟 `nyi`（not yet implemented）：

```janet
(crc/named-variant :crc32)    # ✓
(crc/named-variant :crc32c)   # ✓
(crc/named-variant :crc8)     # ✓
(crc/named-variant :crc-32)   # ✘ error: nyi   ← 只差一個減號
(crc/named-variant :crc64-ecma)  # ✘ error: nyi
```

名字打錯不會有「找不到」這種好懂的訊息，只會給你 `nyi`。要別的多項式用 `make-variant` 自己組。

```janet
(import spork/zip)
(def 壓過 (zip/compress (string/repeat "hello " 20)))   # 120 bytes => 29 bytes
(string (zip/decompress 壓過))                           # 原樣回來
```

## 四、regex：其實是 PEG 的語法糖

Janet 內建的是 **PEG**（[14 PEG 解析器](14-peg.md)），沒有 regex。`spork/regex` 補了 regex 語法——
但它**不是另一套引擎**，是把 regex **翻譯成 PEG** 再交給內建引擎跑：

```janet
(import spork/regex)
(regex/source "[0-9]+")   # => (some (range "09"))   ← 翻出來的 PEG
```

```janet
(regex/find "[0-9]+" "abc123def")          # => 3      ⚠ 回的是索引，不是配到的字串
(regex/replace-all "[0-9]" "#" "a1b2c3")   # => @"a#b#c#"
```

⚠ **`find-all` 找的是「重疊」的起點**：`"abc123def"` 找 `[0-9]+` 會拿到 `@[3 4 5]`
三個索引（從 1、從 2、從 3 各算一次成功），而不是「一段數字」——它每次成功後只往後
推進一個 byte 重試，不跳過整段。這跟一般 regex 的 global match 直覺**完全不同**。

**什麼時候用哪個**：

| 情況 | 用 |
|------|-----|
| 你腦中已經有現成的 regex，只是想跑一下 | `spork/regex` |
| 要解析有結構的東西（設定檔、log、CSV、運算式） | **內建 PEG**（[14](14-peg.md)） |
| 需要遞迴、具名規則、捕獲成結構 | **內建 PEG**（regex 做不到） |

regex 能表達的是 PEG 的**子集**。長期而言學 PEG 比較划算——它是內建的、能力更強。

## 五、date：日期物件，但格式碼會咬人

內建的時間是 Unix 秒（[24 時間與日期](24-時間與日期.md)）。`spork/date` 給你**日期物件**與加減：

```janet
(import spork/date)
(def 今天 (date/utc-now))
(date/to-string 今天 "yyyy-MM-dd")                      # => "2026-08-29"
(date/to-string (date/add 今天 :days 3) "yyyy-MM-dd")   # => "2026-09-01"
(date/leap-year? 2024)                                   # => true
(date/diff 晚的 早的)                                    # 兩個日期差多少
```

## ⚠ 格式 token 大小寫敏感，而且打錯不報錯

```janet
(date/to-string 今天 "yyyy-MM-dd")   # => "2026-08-29"   ✓
(date/to-string 今天 "YYYY-MM-DD")   # => "YYYY-08-DD"   ✘ 但它不報錯！
```

token 是 Java／C# 風格的：**`yyyy` 年、`MM` 月、`dd` 日、`HH` 時、`mm` 分、`ss` 秒**。
注意 **`MM` 是月、`mm` 是分**，大小寫意義完全不同。而 `YYYY`、`DD` **根本不是 token**，
所以它們會**原封不動留在輸出字串裡**——你得到 `"YYYY-08-DD"` 這種東西，
而且完全沒有錯誤訊息。⚠ **格式字串請一定要先跑一次看輸出。**

> 只需要「現在幾點」或「加三天」的話，內建的 `os/time` ＋ `os/strftime` 就夠了
> （[24](24-時間與日期.md)）。要「日期物件、比大小、算兩個日期差幾天」才值得多一個依賴。

## 可跑範例

```sh
janet examples/spork-tour.janet    # 這篇的每個模組都跑了一段
```

下一步：[30-spork-並行與服務.md](30-spork-並行與服務.md)。
