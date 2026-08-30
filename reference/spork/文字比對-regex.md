# 文字比對 ・ spork/regex

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/regex` 是一套「把眼熟的 regex 語法編譯成 Janet 內建 PEG」的轉譯層——**不是**另一套獨立的比對引擎。
Janet 本身沒有傳統 regex，只有 PEG（見 [docs/14-peg.md](../../docs/14-peg.md)）；
`spork/regex` 存在的意義是給只會寫 `\d+` `[a-z]{2,4}` 這種語法、還沒學 PEG 的人一個過渡。

## 這是「一套子集」，不是完整 regex

原始碼開頭寫明支援範圍：單一位元組、跳脫字元、`+ * ? .`、`{n}` `{n,m}` 次數、`[a-z]` 範圍與 `[^...]` 反向字元類、
`|` 選擇（跟 PEG 一樣是**有序**選擇，不是正規 regex 的並行匹配）、`(...)` 捕獲、`(?:...)` 非捕獲群組。
**明確不支援、以後也未必會加**：反向引用、lookahead/lookbehind、命名群組等更進階的 regex 專屬功能——
需要那些的話，原始碼自己也建議「直接用 PEG」。

## 函式一覽

| 函式 | 簽名 | 說明 |
|---|---|---|
| `regex/compile` | `(compile pattern)` | regex 字串 → PEG（已編譯）。如果 `pattern` 本身已經是 PEG，原樣回傳 |
| `regex/source` | `(source pattern)` | regex 字串 → PEG **原始碼**（tuple，還沒編譯），方便看它到底轉成什麼 |
| `regex/match` | `(match reg text &opt start)` | 對應 `peg/match` |
| `regex/find` | `(find reg text &opt start)` | 對應 `peg/find`：回傳**第一個匹配起點的位元組索引**（不是匹配到的字串本身），找不到回 `nil` |
| `regex/find-all` | `(find-all reg text &opt start)` | 對應 `peg/find-all`：回傳所有匹配起點索引的陣列——⚠ 見下方「重疊」問題 |
| `regex/replace` | `(replace reg rep text &opt start)` | 替換第一個匹配 |
| `regex/replace-all` | `(replace-all reg rep text &opt start)` | 替換所有匹配 |
| `regex/peg` | （PEG 值） | 內部用來把 regex 字串解析成 PEG 原始碼的那條 PEG 本身，一般用不到，開放出來是實作細節 |

## 實測：把 regex 轉成 PEG 看得到的樣子

```janet
(import spork/regex :as re)
(re/source "a+b*c?")           # => (* (some "a") (any "b") (? "c"))
(re/source "[A-Za-z]{2,4}")    # => (between 2 4 (range "AZ" "az"))
(re/source "a|b|c")            # => (choice "a" "b" "c")
(re/source "(ab)+")            # => (some (capture "ab"))
(re/source "\\d+")             # => (some (range "09"))
```
對照著看就懂：regex 語法只是 PEG 幾個組合子的糖衣，`{n,m}` 對應 `between`、`?` 對應 `?`、`|` 對應 `choice`。

## 實測：比對與捕獲

```janet
(import spork/regex :as re)
(re/match "(\\d+)-(\\d+)" "123-456")   # => @["123" "456"]     兩個捕獲群組
(re/match "a|b|c" "b")                  # => @[]                成功但沒捕獲（跟 PEG 同樣語意）
```

## ⚠ 實測：`find`／`find-all` 回傳的是「索引」，而且 `find-all` 找的是**重疊**的匹配起點

```janet
(import spork/regex :as re)
(re/find "\\d+" "abc123def456")         # => 3          第一個數字開始的位元組位置，不是 "123"
(re/find-all "\\d+" "abc123def456")     # => @[3 4 5 9 10 11]
```
`"abc123def456"` 裡數字只有兩段（`123` 在 3-5、`456` 在 9-11），但 `find-all` 給了六個索引 `3 4 5 9 10 11`。
這是因為 `peg/find-all`（`regex/find-all` 只是包了一層）**每個位置都重新嘗試匹配，成功了也只往後移 1 個位元組**，
不會跳到這次匹配結束的地方。所以 `123` 這三個字元，從索引 3、4、5 起頭都各自匹配成功一次（`23`、`3` 也是合法的
`\d+`），於是全部被列出來——這是**重疊匹配的起點清單**，不是「有幾段連續數字」。
真的要拿到「有幾段」「每段內容是什麼」，用 `replace-all` 搭配捕獲函式，或直接寫 PEG 用 `(peg/match (compile ~(some (+ (<- (some (range "09"))) 1))) text)` 這類「匹配後前進、不匹配則吃一個位元組」的寫法自己控制前進邏輯。

```janet
(import spork/regex :as re)
(re/replace "\\d+" "#" "abc123def456")       # => "abc#def456"     只換第一段
(re/replace-all "\\d+" "#" "abc123def456")   # => "abc#def#"       全部換掉，這裡沒有重疊問題
```
`replace`／`replace-all` 沒有上面的重疊問題，因為替換语意本身就是「匹配到就跳過整段、換成新內容」，
只有直接查「索引」的 `find`／`find-all` 会曝露 PEG `find-all` 的逐位元組推進行為。

## 什麼時候用哪個

- 只需要眼熟的 `\d+` `[a-z]{2,4}` 這類簡單模式、抄別的語言的 regex 過來改一改 → `spork/regex`。
- 要解巢狀結構（設定檔、DSL、遞迴文法）、要精準控制「匹配後怎麼前進」、要用 `find-all` 拿不重疊的分段結果
  → 直接寫 PEG（見 [docs/14-peg.md](../../docs/14-peg.md)），別繞遠路經過 regex 子集再回頭跟 PEG 的行為打交道。
