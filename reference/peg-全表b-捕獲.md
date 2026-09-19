# PEG ・ 捕獲用 special 21 個

[← reference 索引](README.md)｜函式與比對用 special 在 [peg-全表.md](peg-全表.md)

對應教學：[14 peg](../docs/14-peg.md)。

> 對著 Janet 1.41.2 的 PEG 實作逐一核過，**21 個一個不漏**，每個都跑過 `peg/match`。

比對用的 special 只決定「吃掉多少 byte」，捕獲用的才會**往結果陣列推值**。

## 取出文字

| 語法 | 一句話 | 實測 |
|------|--------|------|
| `(capture p &opt tag)`／`(<- p)`／`(quote p)` | 把 p 吃掉的那段推進結果 | `(peg/match '(capture "ab") "abc")` → `@["ab"]` |
| `(group p &opt tag)` | 把 p 的捕獲收成**一個子陣列** | `(peg/match '(group (* (<- "a") (<- "b"))) "ab")` → `@[@["a" "b"]]` |
| `(accumulate p &opt tag)`／`(% p)` | 把 p 的捕獲**串成一個字串** | `(peg/match '(% (* (<- "a") (<- "b"))) "ab")` → `@["ab"]` |
| `(drop p)` | 照常比對，但**丟掉** p 的捕獲 | `(peg/match '(* (drop (<- "a")) (<- "b")) "ab")` → `@["b"]` |
| `(only-tags p)` | 丟掉捕獲、留下 tag（見[前篇](peg-全表.md)） | — |

`<-` 三個寫法完全等價：`(peg/match '(quote "ab") "abc")` → `@["ab"]`。
`'` 開頭的 peg 裡寫 `(quote p)` 會長得很怪，實務上都用 `<-`。

## 換掉捕獲的值

| 語法 | 一句話 | 實測 |
|------|--------|------|
| `(replace p subst)`／`(/ p subst)` | 用函式／字典／常數改寫 p 的捕獲 | `(peg/match ~(/ (<- :d+) ,scan-number) "42")` → `@[42]` |
| `(cmt p f &opt tag)` | 同上，但 **f 回 `nil` 整條就不比對** | `(peg/match ~(cmt (<- (some "a")) ,length) "aaa")` → `@[3]` |
| `(constant v &opt tag)` | 推一個固定值，不吃 byte | `(peg/match '(* (<- "a") (constant :tag)) "a")` → `@["a" :tag]` |
| `(argument n &opt tag)` | 推 `peg/match` 第 n 個額外參數 | `(peg/match '(argument 0) "a" 0 :hello)` → `@[:hello]` |

⚠ `replace` 跟 `cmt` 的差別只有一個：**`cmt` 的函式回 `nil` 等於比對失敗**，`replace` 不會。
要「解析得出來才算數」用 `cmt`，純轉換用 `replace`。

`subst` 給字典也行：`(peg/match '(replace (<- "a") {"a" :A}) "a")` → `@[:A]`。

## 推位置

| 語法 | 一句話 | 實測 |
|------|--------|------|
| `(position &opt tag)`／`($)` | 目前的 byte 位移 | `(peg/match '(* "ab" ($)) "abc")` → `@[2]` |
| `(line &opt tag)` | 目前行號，**從 1 起算** | `(peg/match '(* "a\nb" (line) (column)) "a\nbc")` → `@[2 2]` |
| `(column &opt tag)` | 目前欄號，**從 1 起算** | 同上 |

## 反向參照

| 語法 | 一句話 | 實測 |
|------|--------|------|
| `(backref tag &opt newtag)`／`(-> tag)` | 把 tag 那個捕獲**再推一次** | `(peg/match '(* (<- "a" :x) "b" (-> :x)) "ab")` → `@["a" "a"]` |
| `(backmatch &opt tag)` | 要求接下來的文字**跟 tag 一模一樣** | `(peg/match '(* (<- "ab" :x) (backmatch :x)) "abab")` → `@["ab"]` |
| `(unref p &opt tag)` | p 跑完後把裡面的 tag **清掉** | 見下 |

tag 從哪來：任何捕獲 special 的最後一個參數。`(<- "a" :x)` 就是「捕獲並取名 `:x`」。

```janet
(peg/match '(* (unref (* (<- "a" :x) (-> :x))) (<- "b")) "ab")  # => @["a" "a" "b"]
(peg/match '(* (unref (* (<- "a" :x) (-> :x))) (-> :x)) "ab")   # => nil
```

第二行 `nil`：`unref` 外面已經查不到 `:x`。寫遞迴文法時用它避免同名 tag 互相汙染。

## 讀二進位

| 語法 | 一句話 | 實測 |
|------|--------|------|
| `(number p &opt base tag)` | 把 p 吃到的文字**當數字 parse** | `(peg/match '(number 2) "42x")` → `@[42]` |
| `(int n &opt tag)` | n 個 byte 的**有號**整數，little-endian | `(peg/match '(int 1) "\xff")` → `@[-1]` |
| `(int-be n &opt tag)` | 同上但 big-endian | `(peg/match '(int-be 2) "AB")` → `@[16706]` |
| `(uint n &opt tag)` | n 個 byte 的**無號**整數，little-endian | `(peg/match '(uint 1) "\xff")` → `@[255]` |
| `(uint-be n &opt tag)` | 同上但 big-endian | `(peg/match '(uint-be 2) "AB")` → `@[16706]` |
| `(lenprefix n p)` | 先用 n 讀出一個數字 k，再跑 p **k 次** | `(peg/match '(lenprefix (number 1) (<- 1)) "3abcd")` → `@["a" "b" "c"]` |

`number` 吃第二個參數當進位：`(peg/match '(number :w+ 16) "ff")` → `@[255]`。

⚠ `int`／`uint` 預設是 **little-endian**（`"AB"` → `16961`），跟網路序相反；
讀網路封包要用 `-be` 那組（`"AB"` → `16706`）。

## 主動報錯

| 語法 | 一句話 |
|------|--------|
| `(error &opt p)` | p 比對成功就**丟 Janet error**；p 省略時用預設訊息 |

```janet
(protect (peg/match '(* "a" (error (<- "b"))) "ab"))
# => (false "b")
(protect (peg/match '(* (<- "a") (error)) "ab"))
# => (false "match error at line 1, column 2")
```

⚠ `(error p)` 的 p **要比對成功錯誤才會丟**。p 不成立時整條 `error` 只是普通的失敗，
回 `nil` 而已——寫成 `(error "expected }")` 是常見的誤會，那是「看到 `expected }` 這串字才報錯」。

## 具名文法

peg 給一個 struct／table 就是具名文法，`:main` 是入口：

```janet
(peg/match '{:main (* :num "+" :num) :num (number :d+)} "12+34")  # => @[12 34]
```
