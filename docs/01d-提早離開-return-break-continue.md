# 01d · 提早離開：return、break、continue 在 Janet 怎麼寫

[← 01b 給 C++ 開發者](01b-給-C++-開發者.md) 是一張概念對照表。這篇只講一件事：
C／Lua／Go 裡「跳出去」的那幾個關鍵字，在 Janet 對到什麼。簽名查 [reference/控制流](../reference/控制流.md)，
`loop` 的條件詞在 [32b](32b-loop-全表.md)。

## 先講結論

| C／C++ | Lua | Go | Janet |
|--------|-----|----|-------|
| `return x;` 在函式最後 | `return x` | `return x` | 不用寫，**最後一個運算式就是回傳值** |
| `if (c) return x;` | `if c then return x end` | `if c { return x }` | 改寫成分支 `(if c x …)`；真要中途離開就 `(when c (break x))` |
| `break;` | `break` | `break` | `(break)`；`(break 值)` 的值**會被丟掉** |
| `continue;` | `goto continue` | `continue` | 沒有。用 `loop` 的 `:when`／`:unless`，或 `(unless 條件 …)` 包住 body |
| `goto out;` 跳出巢狀 | `goto out` | `break outer` | `label` ＋ `return` |
| `longjmp` | `error`／`pcall` | `panic`／`recover` | `prompt`／`return`；錯誤走 `error`／`try`（[20](20-錯誤處理與資源管理.md)） |
| | `return a, b` | `return a, b` | `[a b]` ＋ 解構（[01c](01c-解構與執行緒巨集.md)） |

## 回傳值就是最後一個運算式

C 裡三個 `return`，Janet 裡是三個分支。心法：**把「早退」改寫成「分支」**。

```janet
(defn sign [n] (cond (< n 0) :負 (zero? n) :零 :正))
(map sign [-5 0 3])   # => @[:負 :零 :正]
```

## 真的要中途離開函式：break

`break` 有兩個身分。在 `while` 裡是跳出迴圈；**不在迴圈裡、直接在函式 body 裡時，它就是 return**：

```janet
(defn safe-div [a b]
  (when (zero? b) (break :除以零))
  (/ a b))
(safe-div 1 0)   # => :除以零
(safe-div 6 3)   # => 2
```

⚠ 它只認**最內層的 `while` 或 `fn`**。`each`／`for`／`loop` 展開後底下都是 `while`
（`(macex1 '(each x xs …))` 看得到），所以在裡面 `break` 只出迴圈、不出函式：

```janet
(defn f [] (each x [1 2 3] (when (= x 2) (break))) :跑完)
(f)   # => :跑完
```

⚠ `(break 值)` 在迴圈裡，值會被丟掉，迴圈本身一律回 `nil`：

```janet
(each x [1 2 3] (when (= x 2) (break x)))   # => nil
(while true (break 42))                      # => nil
```

要把找到的東西帶出來，先 `(var 答 nil)`，圈內 `(set 答 x) (break)`，最後一行寫 `答`；
或用下面的 `label`。`find`／`find-index`／`some` 已經幫你做好這件事（[25](25-序列工具.md)）。

### ⚠ try／defer／with 裡的 break 跳不出外面的迴圈

這三個巨集都把 body 包進一個隱藏的 `fn`（各自跑在一個 fiber 上），`break` 只離開那個 `fn`：

```janet
(def log @[])
(each x [1 2 3]
  (defer (array/push log [:收尾 x])
    (when (= x 2) (break))
    (array/push log [:body x])))
log   # => @[(:body 1) (:收尾 1) (:收尾 2) (:body 3) (:收尾 3)]
```

`x=2` 的 body 被跳過、收尾有跑，**但 `x=3` 照樣進來**。
[20b](20b-資源管理.md) 的範例是迴圈在 `defer` 裡面，那樣沒事；反過來包就會這樣。要跳出迴圈，用 `label`。

## continue：用過濾，不用跳

```janet
(seq [i :range [0 6] :unless (= i 2)] i)   # => @[0 1 3 4 5]
(def r @[])
(each x [1 2 3 4] (unless (even? x) (array/push r x)))
r   # => @[1 3]
```

`:when`／`:unless` 只過濾不中止；`:while`／`:until` 才中止（[32b](32b-loop-全表.md)）。

## 跳出巢狀迴圈：label ＋ return

C 用 `goto`，Go 用 `break outer`。Janet 在外圈套一個 `label`：

```janet
(label outer
  (for i 0 3
    (for j 0 3
      (when (= [i j] [1 2]) (return outer [i j])))))   # => (1 2)
```

沒人 `return` 時回最後一個運算式；`(return out)` 不給值就是 `nil`。
「continue 到外層」就把 `label` 套在**內圈**：

```janet
(seq [i :range [0 3]]
  (label next
    (for j 0 3 (when (= j 1) (return next [i :跳])))
    [i :跑完]))   # => @[(0 :跳) (1 :跳) (2 :跳)]
```

它底下是什麼：`label` 做一個獨一無二的 tag 綁到那個名字，body 跑在攔 user0 信號的 fiber 裡；
`return` 是普通函式，做的事是 `(signal 0 [tag 值])`。兩個推論，都實測過：

- 名字是**詞法**的：`(return nowhere 1)` 是編譯錯 `unknown symbol nowhere`。
- **能跨函式**：在 `label` 裡定義的閉包呼叫 `(return outer …)` 一樣跳得回去。
  但閉包若在 `label` 結束後才被呼叫，信號沒人接，程式直接死（見下）。

## prompt：tag 是任意值的 label

`prompt` 的 tag 通常是 keyword，不必在同一個詞法範圍，適合「深處的函式想直接回到最上面」：

```janet
(defn 找到就回 [] (return :out :跳))
(prompt :out (找到就回) :沒跳)   # => :跳
```

⚠ 找不到對應的 `prompt` 時，**`try` 攔不到**——它是 user0 信號不是 error。
程式終止並印 `user0: <tuple 0x…>`。能接住它的只有 `(fiber/new f :u)`：

```janet
(def k (fiber/new (fn [] (try (return :q :跳) ([e] :try攔到))) :u))
(resume k)          # => (:q :跳)
(fiber/status k)    # => :user0
```

## fiber／signal 什麼時候才需要

`label`／`prompt` 已經是 fiber ＋ signal 的糖。自己動手只在兩種情況：想用 user1～9 區分**多種**跳出，
或想在 `resume` 端決定接下來做什麼（[09 手動攔信號](09-fiber.md)）：

```janet
(def f (fiber/new (fn [] (for i 0 10 (when (= i 3) (signal 1 [:找到 i]))) :跑完) :u))
(resume f)          # => (:找到 3)
(fiber/status f)    # => :user1
```

## 可跑範例

```sh
janet examples/early-exit.janet
```

每個情境印「C 的寫法 → Janet 的寫法 → 實際結果」。

下一步：[43 從 C／C++ 過來](43-從-C-C++-過來.md)、[44 從 Lua 過來](44-從-Lua-過來.md)、[45 從 Go 過來](45-從-Go-過來.md) 逐條對照日常語法。
