# PEG 速查

Janet 內建的解析器：比 regex 強，能解巢狀（Janet 1.41.2 實測）

## PEG · 內建解析器

不用 import。比 regex 強在**解得了巢狀**；要 quote（`~` 才能用 `,` 挖洞）。

```janet
(peg/match ~(* (<- (some (range "az"))) "=" (<- (some (range "09")))) "key=42")
;=> @["key" "42"]
```

> ⚠ **★ 沒捕獲時成功回 `@[]`**（空陣列是真值），失敗才回 `nil`。判斷成敗用 `(nil? r)`。

### 組合子

| 寫法 | 意思 | 寫法 | 意思 |
|---|---|---|---|
| `"abc"` | literal | `(* a b)` | 依序 |
| `n` | 吃 n 個位元組 | `(+ a b)` | 擇一（有序！） |
| `-1` | 到結尾 | `(any p)`／`(some p)` | 0+ ／ 1+ |
| `(range "az")` | 字元範圍 | `(between n m p)` | 次數範圍 |
| `(set "aeiou")` | 其中之一 | `(? p)`／`(if-not p q)` | 可有可無／負向 |

### 捕獲

| 寫法 | 意思 | 寫法 | 意思 |
|---|---|---|---|
| `(<- p)` | 捕字串 | `(/ p f)` | 捕完丟給 f（轉型） |
| `(group p)` | 包成 array | `(% p)` | 串成一個字串 |
| `(constant v)` | 不吃字元、直接產值 | `($)` | 目前位置 |

### 具名文法（可遞迴）

```janet
(def ip ~{:byte (/ (<- (between 1 3 (range "09"))) ,scan-number)
           :main (* :byte "." :byte "." :byte "." :byte -1)})
(peg/match ip "192.168.1.7") ;=> @[192 168 1 7]

# 遞迴：括號配對（regex 做不到）
~{:main (* :expr -1)
  :expr (any (+ (* "(" :expr ")") (if-not (set "()") 1)))}
```

### 另外三個 API

```janet
(peg/find p s) (peg/find-all p s)   ;=> 索引 / @[索引…]
(peg/replace-all p "#" s)          ;=> ★ 回 buffer
(peg/compile p)                     # 重複用先編譯
```

| 症狀 | 正解 |
|---|---|
| `,scan-number` unknown symbol | 用了 `'(…)`；挖洞要 `~(…)` |
| 只比對前半段就算成功 | PEG 不強制吃完，結尾加 `-1` |
| `(+ "cat" "cattle")` 只比到 cat | 有序選擇、不回溯。長的具體的放前面 |

細節 `docs/14`，可跑 `examples/peg-demo.janet`。
