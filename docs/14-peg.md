# 14 · PEG：Janet 的招牌解析器

PEG（Parsing Expression Grammar）是 Janet **內建**的解析器，不用 import。它在
「比 regex 難、比手寫 parser 簡單」這一格，而且**解得了巢狀結構**——regex 做不到這件事。

要解 log、設定檔、簡單 DSL、路徑、版本號、CSV，第一個想到它。

```janet
(peg/match ~(* (<- (some (range "az"))) "=" (<- (some (range "09")))) "key=42")
;=> @["key" "42"]
```

## 心智模型

- 一條 PEG 是**一個 pattern**，用 tuple 組合起來。所以要 quote：`'(...)` 或 `~(...)`。
- 有 `~` 才能用 `,` 挖洞把 Janet 函式塞進去（見下面的 `/`）。
- `peg/match` **從字串開頭比對**，成功回傳「捕獲的陣列」，失敗回 `nil`。
- **沒有捕獲時成功會回 `@[]`**——空陣列在 Janet 是真值，別誤判成失敗。

```janet
(peg/match '(some (range "az")) "hello123")   ;=> @[]     ← 成功，但沒捕獲
(peg/match '(some (range "az")) "123")        ;=> nil     ← 失敗
```

## 基本組合子

| 寫法 | 意思 |
|------|------|
| `"abc"` | literal，比對這串字 |
| `n`（正整數） | 吃掉 n 個位元組 |
| `-1` | 到字串結尾（`(not 1)`） |
| `(range "az" "AZ")` | 字元範圍，可給多段 |
| `(set "aeiou")` | 這幾個字元之一 |
| `(* a b c)` | 依序（sequence，像 `and`） |
| `(+ a b c)` | 擇一（choice，像 `or`，由左往右試） |
| `(any p)` | 零或多次 |
| `(some p)` | 一或多次 |
| `(between n m p)` / `(repeat n p)` | 次數範圍 / 剛好 n 次 |
| `(? p)` / `(opt p)` | 零或一次 |
| `(if-not p q)` / `(not p)` | 負向前瞻 |
| `(look n p)` | 位移 n 之後再看 p（不吃字元） |

## 捕獲

| 寫法 | 做什麼 |
|------|--------|
| `(capture p)` / `(<- p)` | 捕獲比對到的字串 |
| `(replace p subst)` / `(/ p f)` | 捕獲後丟給函式／值換掉 |
| `(constant v)` | 不吃字元，直接產出一個常數 |
| `(group p)` | 把裡面的捕獲包成一個 array |
| `(accumulate p)` / `(% p)` | 把裡面的捕獲串成一個字串 |
| `(cmt p f)` | 捕獲並呼叫 f，f 回 nil 就整條算失敗 |
| `(position)` / `($)` | 目前位置（數字） |

```janet
# 捕獲時順手轉型：, 挖洞把 scan-number 塞進去
(peg/match ~(/ (<- (some (range "09"))) ,scan-number) "42")   ;=> @[42]
```

## 具名文法：解巢狀的關鍵

用 struct/table 當文法，key 是規則名（keyword），`:main` 是進入點，規則之間可以互相引用
（包括**遞迴引用自己**）——這就是 regex 做不到的地方。

```janet
(def ip-grammar
  ~{:byte (/ (<- (between 1 3 (range "09"))) ,scan-number)
    :main (* :byte "." :byte "." :byte "." :byte -1)})

(peg/match ip-grammar "192.168.1.7")   ;=> @[192 168 1 7]
(peg/match ip-grammar "1.2.3")         ;=> nil
```

遞迴的例子（配對括號）：

```janet
(def balanced
  ~{:main (* :expr -1)
    :expr (any (+ (* "(" :expr ")") (if-not (set "()") 1)))})
(peg/match balanced "(a(b)c)")   ;=> @[]   成功
(peg/match balanced "(a(b)c")    ;=> nil
```

## 四個常用 API

```janet
(peg/match peg text &opt start & args)   # 從頭比對，回捕獲或 nil
(peg/find peg text)                      # 找第一個出現位置 => 索引或 nil
(peg/find-all peg text)                  # 全部位置 => @[…]
(peg/replace-all peg subst text)         # 取代全部 => buffer
(peg/compile peg)                        # 先編譯，重複使用時省時間
```

```janet
(peg/find ~(* "b" "c") "abcabc")                    ;=> 1
(peg/find-all "ab" "abXab")                         ;=> @[0 3]
(peg/replace-all ~(some (range "09")) "#" "a1b22c333")  ;=> @"a#b#c#"
```

> `peg/replace-all` 回傳 **buffer**，要字串再包一層 `(string …)`。

## 實用例：解一行 log

```janet
(def log-line
  ~{:ws     (any (set " \t"))
    :level  (/ (<- (+ "INFO" "WARN" "ERROR")) ,keyword)
    :num    (/ (<- (some (range "09"))) ,scan-number)
    :rest   (<- (any 1))
    :main   (* "[" :num "]" :ws :level :ws :rest)})

(peg/match log-line "[1234] ERROR 連不上資料庫")
;=> @[1234 :ERROR "連不上資料庫"]
```

一次搞定：切欄位、轉數字、轉 keyword。同樣的事用 `string/split` 會寫成一堆 index 運算。

## 跟 regex 的關係

真的想寫 regex，spork 有轉譯器：

```janet
(import spork/regex)
(peg/match (regex/compile "a+b") "aaab")   ;=> @[]
```

但寫新東西建議直接寫 PEG——可讀、可組合、可遞迴，而且不用背跳脫規則。

## 地雷

| 症狀 | 原因 / 正解 |
|------|------------|
| 成功卻拿到 `@[]` 以為失敗 | 沒有捕獲時就是空陣列。要判斷成敗用 `(nil? result)` |
| `,scan-number` 說 unknown symbol | 用了 `'(...)` 不能挖洞，要換 `~(...)` |
| 比對到一半就成功，後面沒檢查 | PEG 不強制吃完整串，結尾要自己加 `-1` |
| `(+ a b)` 選錯分支 | PEG 的 `+` 是**有序**選擇、不回溯已成功的分支。把長的、具體的放前面 |
| `peg/replace-all` 結果印出來怪怪的 | 回的是 buffer，`(string …)` 一下 |

---

可跑範例與更多花樣見 [`examples/peg-demo.janet`](../examples/peg-demo.janet)。

下一步：[15-ev-channel-net.md](15-ev-channel-net.md)。
