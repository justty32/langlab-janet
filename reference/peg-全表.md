# PEG ・ 函式 6 個 ＋ 比對用 special 21 個

[← reference 索引](README.md)｜捕獲那半邊在 [peg-全表b-捕獲.md](peg-全表b-捕獲.md)

對應教學：[14 peg](../docs/14-peg.md)。速查：[html/peg.html](../html/peg.html)。

> 對著 `root-env` 逐一核過：`peg/*` **6 個**全收，另加 `default-peg-grammar`。
> PEG 文法的 special **42 個**（本篇 21 個比對用，[b 篇](peg-全表b-捕獲.md) 21 個捕獲用），
> 每個都跑過一次 `peg/match`。

## `peg/*`（6 個）

| 函式 | 簽名 | 回什麼 |
|------|------|--------|
| `peg/match` | `(peg/match peg text &opt start & args)` | 捕獲陣列；**沒捕獲就是 `@[]`**，不比對才是 `nil` |
| `peg/compile` | `(peg/compile peg)` | 編成 `:core/peg`；同一個 peg 要用很多次就先編 |
| `peg/find` | `(peg/find peg text &opt start & args)` | 第一個比對成功的索引，或 `nil` |
| `peg/find-all` | `(peg/find-all peg text &opt start & args)` | 所有索引的陣列 |
| `peg/replace` | `(peg/replace peg subst text &opt start & args)` | 換掉**第一個**，回新 buffer |
| `peg/replace-all` | `(peg/replace-all peg subst text &opt start & args)` | 換掉**全部**，回新 buffer |

```janet
(peg/find '"b" "abcb")                     # => 1
(peg/find-all '"b" "abcb")                 # => @[1 3]
(string (peg/replace '"b" "X" "abcb"))     # => "aXcb"
(string (peg/replace-all '"b" "X" "abcb")) # => "aXcX"
(type (peg/compile '(<- "a")))             # => :core/peg
```

⚠ **`@[]` 跟 `nil`是兩回事**：`@[]` 是「比對成功但沒有捕獲」，`nil` 才是「不比對」。
判斷成功用 `(nil? r)`，不要用 `(empty? r)`。

⚠ `peg/replace*` 回的是 **buffer** 不是 string，要 `(string …)` 包一層才能跟字串比較。

## 三種原始 pattern（不用 special 包）

| 寫法 | 意思 | 例 |
|------|------|-----|
| 字串 | 比對這串字面值 | `(peg/match '(<- "abc") "abcdef")` → `@["abc"]` |
| 正整數 `n` | 吃掉 n 個 byte（要夠長） | `(peg/match '(<- 3) "abcdef")` → `@["abc"]` |
| 負整數 `-n` | 剩下**不足** n 個 byte 才成功；`-1` ＝ 字串結尾 | `(peg/match '(* -1) "")` → `@[]` |
| keyword | 查文法表裡的規則名（見下） | `(peg/match '(<- :w) "abc")` → `@["a"]` |

## `default-peg-grammar`（30 個內建規則名）

```janet
(sort (keys default-peg-grammar))
# => @[:A :A* :A+ :D :D* :D+ :H :H* :H+ :S :S* :S+ :W :W* :W+ :a :a* :a+ :d :d* :d+ :h :h* :h+ :s :s* :s+ :w :w* :w+]
```

小寫是「是這一類」、大寫是「**不是**這一類」；`*` ＝ 零個以上、`+` ＝ 一個以上。
`a` 字母、`d` 數字、`h` 十六進位、`s` 空白、`w` 文數字（word）。

```janet
(peg/match '(<- :d+) "123x")    # => @["123"]
(peg/match '(<- :a+) "ab1")     # => @["ab"]
(peg/match '(<- :h+) "ffzz")    # => @["ff"]
(peg/match '(<- :s+) "  x")     # => @["  "]
```

⚠ 換掉這張表用 `(dyn :peg-grammar)`，不是改 `default-peg-grammar` 本身。

## 比對用 special（21 個）

「吃掉多少 byte」的那組，本身不產生捕獲。

| 語法 | 一句話 | 實測 |
|------|--------|------|
| `(set "…")` | 這些字元裡的任一個 | `(peg/match '(<- (any (set "aeiou"))) "eaix")` → `@["eai"]` |
| `(range "az" "09")` | 字元區間，可給多段 | `(peg/match '(<- (any (range "az" "09"))) "a9Z")` → `@["a9"]` |
| `(any p)` | 零個以上，**永遠成功** | `(peg/match '(<- (any "a")) "bbb")` → `@[""]` |
| `(some p)` | 一個以上 | `(peg/match '(<- (some "a")) "aaab")` → `@["aaa"]` |
| `(between n m p)` | n 到 m 次，貪婪 | `(peg/match '(<- (between 2 3 "a")) "aaaa")` → `@["aaa"]` |
| `(at-least n p)` | 至少 n 次 | `(peg/match '(<- (at-least 2 "a")) "aaa")` → `@["aaa"]` |
| `(at-most n p)` | 至多 n 次 | `(peg/match '(<- (at-most 2 "a")) "aaa")` → `@["aa"]` |
| `(repeat n p)` | **剛好** n 次；不足就失敗 | `(peg/match '(repeat 4 "a") "aaa")` → `nil` |
| `(opt p)`／`(? p)` | 零或一次 | `(peg/match '(<- (? "x")) "abc")` → `@[""]` |
| `(sequence a b)`／`(* a b)` | 依序全中 | `(peg/match '(<- (* "a" "b")) "abc")` → `@["ab"]` |
| `(choice a b)`／`(+ a b)` | **由左至右**第一個中的 | `(peg/match '(<- (+ "x" "ab")) "abc")` → `@["ab"]` |
| `(not p)`／`(! p)` | p **不**成立才成功，不吃 byte | `(peg/match '(* (! "x") (<- 3)) "abc")` → `@["abc"]` |
| `(if c p)` | c 成立才試 p（c 不吃 byte） | `(peg/match '(* (if "a" (<- 3))) "abc")` → `@["abc"]` |
| `(if-not c p)` | c **不**成立才試 p | `(peg/match '(* (if-not "x" (<- 3))) "abc")` → `@["abc"]` |
| `(look n p)`／`(> n p)` | 偷看偏移 n 處是不是 p，不吃 byte | `(peg/match '(* (look 2 "c") (<- 2)) "abc")` → `@["ab"]` |
| `(to p)` | 一路吃到 p **之前**（不含 p） | `(peg/match '(<- (to "c")) "abcd")` → `@["ab"]` |
| `(thru p)` | 一路吃到 p **之後**（含 p） | `(peg/match '(<- (thru "c")) "abcd")` → `@["abc"]` |
| `(sub w p)` | 先用 w 圈出一段，p 只能在那段裡跑 | `(peg/match '(sub (to ",") (<- (some (range "az")))) "abc,def")` → `@["abc"]` |
| `(split sep p)` | 用 sep 切開，每段各跑一次 p | `(peg/match '(split "," (<- (to -1))) "a,,b")` → `@["a" "" "b"]` |
| `(nth i p)` | 只留 p 產生的第 i 個捕獲 | `(peg/match '(nth 1 (* (<- "a") (<- "b"))) "ab")` → `@["b"]` |
| `(only-tags p)` | 丟掉 p 的捕獲，但 tag 還查得到 | `(peg/match '(* (only-tags (<- "a" :x)) (-> :x)) "a")` → `@["a"]` |

⚠ `(choice …)` **沒有回溯挑最長的**：`(+ "cat" "cattle")` 碰到 `"cattle"` 只會吃到 `cat`。長的要寫前面。

⚠ `(to p)`／`(thru p)` 的 p 找不到時整條失敗，不是「吃到結尾」。想吃到結尾寫 `(to -1)`。

捕獲用的 21 個 special 在 [peg-全表b-捕獲.md](peg-全表b-捕獲.md)。
