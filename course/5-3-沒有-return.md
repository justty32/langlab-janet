# 5-3 · 沒有 return

從 C、Python、JS 過來的人，寫到第一個函式就會卡住：Janet 沒有 `return` 這個關鍵字。那「條件不對就先離開」要怎麼寫？這課把「早退」的各種情況一個一個對上 Janet 的寫法。學完你會知道什麼時候改寫成分支、什麼時候用 `break`、什麼時候用 `label`。

## 這是什麼、為什麼

在 Janet 裡，函式的回傳值就是 body 最後一個運算式的值。你不用寫 `return`，最後算出來的那個東西自動就是答案。

這行得通，是因為 `if`、`cond` 這些都是運算式（expression，會算出一個值的東西），不是 C 那種只負責「決定走哪條路」的陳述句。一個 `cond` 走進哪個分支，整個 `cond` 就等於那個分支的值。所以 C 裡寫三個 `return` 的函式，在 Janet 就是三個分支。

心法只有一句：把「早退」改寫成「分支」。大部分時候這樣就夠了，剩下少數真的要中途跳走的情況，才用這課後半的 `break` 和 `label`。

## 動手

### 最後一個值就是回傳值

C 會這樣寫：`if (n < 0) return NEG; if (n == 0) return ZERO; return POS;`。Janet 直接寫成一個 `cond`：

```janet
(defn sign [n]
  (cond (< n 0) :neg (zero? n) :zero :pos))
(map sign [-5 0 3])   # => @[:neg :zero :pos]
```

`cond` 從上往下找第一個成立的條件，回傳它後面那個值；最後單獨一個 `:pos` 是「都不成立時」的預設。整個 `cond` 是 body 的最後一個運算式，所以它的值就是 `sign` 的回傳值。

### 真的要中途離開函式：break

有時候改寫成分支會讓程式縮排很深，例如開頭先檢查參數。這時用 `break`。`break` 直接寫在函式 body 裡（不在任何迴圈裡）的時候，意思就是「現在帶著這個值離開函式」，等於別的語言的 `return`：

```janet
(defn safe-div [a b]
  (when (zero? b) (break :div-by-zero))
  (/ a b))
(safe-div 1 0)   # => :div-by-zero
(safe-div 6 3)   # => 2
```

`b` 是 0 時，`break` 帶著 `:div-by-zero` 離開，下面的 `(/ a b)` 根本不會跑。`b` 不是 0 就照常走到最後一行。

### 帶值出迴圈：var 加 break

迴圈裡的 `break` 會帶不出值（下一節「坑二」講為什麼）。想要「找到第一個符合的就停，並把它拿出來」，就先準備一個變數接：

```janet
(defn first-big [xs]
  (var found nil)
  (each x xs (when (> x 10) (set found x) (break)))
  found)
(first-big [3 12 40])   # => 12
(first-big [1 2])       # => nil
```

找到就 `set` 進 `found` 再 `break` 出迴圈，最後一行寫 `found` 當回傳值。沒找到的話 `found` 保持 `nil`。

這種「找第一個」其實很常見，Janet 內建的 `find` 已經幫你寫好了；只想知道「有沒有」就用 `some`：

```janet
(find |(> $ 10) [3 12 40])   # => 12
(some |(> $ 10) [3 12 40])   # => true
```

`|(> $ 10)` 是一個小函式的簡寫，`$` 代表傳進來的那個值，6-2 會細講。

### 沒有 continue：用過濾

Janet 也沒有 `continue`。想跳過某幾圈，就換個想法：不是「跳過」，而是「只處理符合的」。`seq` 和 `loop` 有 `:when`、`:unless` 可以直接過濾：

```janet
(seq [i :range [0 6] :unless (= i 2)] i)   # => @[0 1 3 4 5]
```

`:unless (= i 2)` 的意思是 `i` 等於 2 那圈不跑 body，其他圈照跑，迴圈不會中止。用 `each` 的話，就拿 `unless` 把 body 包起來，效果一樣：

```janet
(def r @[])
(each x [1 2 3 4] (unless (even? x) (array/push r x)))
r   # => @[1 3]
```

### 跳出兩層迴圈：label 加 return

C 用 `goto`、Go 用 `break outer` 跳出巢狀迴圈。Janet 用 `label`：在外面套一層 `(label 名字 ...)`，裡面任何地方寫 `(return 名字 值)`，就會直接跳到那層 `label` 外面，整個 `label` 的值就是你給的那個值。

```janet
(label out
  (for i 0 3
    (for j 0 3
      (when (= [i j] [1 2]) (return out [i j])))))   # => (1 2)
```

`i` 是 1、`j` 是 2 的時候，`return` 一口氣跳出兩層 `for`，帶著 `[1 2]` 出來。注意這裡的 `return` 是一個普通函式，後面一定要接 `label` 的名字，跟 C 的 `return` 不是同一回事。

如果都沒有人 `return`，`label` 的值就是它 body 最後一個運算式。`label` 的名字是詞法的，意思是它只在 `label` 那對括號裡面看得到，寫錯名字在編譯時就會報錯。下面用 `eval` 把一段程式碼當場編譯來示範，`protect` 負責把錯誤接住變成值：

```janet
(protect (eval '(label out (return nowhere 1))))   # => (false "unknown symbol nowhere")
```

在函式裡真的要「從迴圈深處帶值直接離開」，最乾淨的寫法就是把整個 body 套進 `label`：

```janet
(defn find-pair [target]
  (label done
    (for i 0 5
      (for j 0 5
        (when (= (+ i j) target) (return done [i j]))))
    nil))
(find-pair 3)    # => (0 3)
(find-pair 99)   # => nil
```

`label` 底下是用 fiber（Janet 可以暫停、跳出的執行單位）做的，10-1 會講，現在當它是「會帶值的 goto」就好。這個比喻不準的地方是它只能往外跳到包住你的那層 `label`，不能跳到任意位置。

## 你會踩的坑

⚠ 坑一：迴圈裡的 `break` 不會離開函式。

你會以為在函式裡的 `each` 中寫 `break`，就跟 C 在迴圈裡寫 `return` 一樣，整個函式結束。其實它只跳出迴圈，函式會繼續往下跑。因為 `break` 只認最內層的 `while` 或函式，而 `each`、`for`、`loop` 展開後底下都是 `while`，所以 `break` 被那個 `while` 接走了。

```janet
(defn f [] (each x [1 2 3] (when (= x 2) (break))) :done)
(f)   # => :done
```

⚠ 坑二：迴圈裡 `(break 值)` 的值會不見。

你會以為 `(break x)` 可以把 `x` 帶出迴圈。其實迴圈本身一律回 `nil`，你給的值被丟掉。因為 `each`、`while` 這些迴圈設計上就只回 `nil`，`break` 在迴圈裡只負責「停」，不負責「帶東西」。

```janet
(each x [1 2 3] (when (= x 2) (break x)))   # => nil
(while true (break 42))                      # => nil
```

要帶值出來，用上面的 `var` 加 `break`、內建的 `find`，或 `label` 加 `return`。

⚠ 還有一個之後才會碰到的：在 `try`、`defer` 裡面寫 `break`，跳不出包在外面的迴圈，因為它們會把 body 偷偷包進一個看不見的函式。7-1、7-2 教到它們時再回頭看，細節在 docs/01d。

## 小練習

1. 寫 `(clamp n)`：`n` 小於 0 回 `0`，大於 100 回 `100`，其他回 `n` 本身。不准用 `break`。
2. 寫 `(first-neg xs)`：回傳 `xs` 裡第一個負數，沒有就回 `nil`。先用 `var` 加 `break` 寫一次，再用 `find` 寫一次。
3. 給一個格子 `[[1 2 3] [4 0 6] [7 8 0]]`，寫 `(find-zero g)` 回傳第一個 0 的座標 `[列 行]`，找不到回 `nil`。用 `label`。答案在 `examples/course/5-3.janet` 最後面。

## 想更深

- [docs/01d 提早離開](../docs/01d-提早離開-return-break-continue.md)：C、Lua、Go 逐條對照表，`try`／`defer` 裡 `break` 的實測細節，以及 tag 可以是任意值的 `prompt`。
- [docs/25 序列工具](../docs/25-序列工具.md)：`find`、`find-index`、`some` 這些讓你根本不用寫 `break` 的工具。

下一課：[6-1 · 函式與參數](6-1-函式與參數.md)
