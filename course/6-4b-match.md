# 6-4b · match（續）

接著[上篇](6-4-match.md)。這篇講 match 剩下幾條規則，再講它最會害人的一個坑，最後用它寫一個小直譯器。

## 動手（續）

### 同一個名字寫兩次：要求兩格相等

```janet
(match [1 1] [a a] :same _ :diff)   # => :same
(match [1 2] [a a] :same _ :diff)   # => :diff
```

模式 `[a a]` 裡 `a` 出現兩次，意思是「第 0 格和第 1 格要是同一個值」。`[1 1]` 對上，`[1 2]` 對不上。

### `&` 收尾：剩下的全拿

```janet
(match [1 2 3 4] [a & rest] [a rest])   # => (1 (2 3 4))
```

跟 6-1 的 `&` 參數一樣，`& rest` 把後面剩下的全部收成一個 tuple。

### 巢狀：模式裡還有模式

```janet
(match {:pos [3 4]} {:pos [x y]} (+ x y))   # => 7
```

字典模式裡的值又是一個 tuple 模式。match 一路往下拆，拿到 `x` 是 3、`y` 是 4。

### array 也吃

```janet
(match @[1 2] [a b] [a b])   # => (1 2)
```

值是 array（可以改的一串值），模式寫成 tuple 照樣對得上。這點跟 `case` 不同：3-3 講過 `=` 對 array 比的是「是不是同一個物件」，所以 array 在 `case` 裡永遠不中。match 是一格一格去比，不看身分。

## 你會踩的坑

⚠ 沒有一個中，也沒寫 `_`。

你會以為所有模式都落空時，match 會報錯提醒你。其實它安靜地回 nil：

```janet
(match 99 0 :zero)   # => nil
```

因為 match 跟 `cond`、`case` 一樣，沒中就是 nil，這是設計。後果是你漏寫一種情況時，錯誤不會出現在 match 這裡，而是 nil 往後流，在別的地方才炸。不確定能不能涵蓋所有情況，就在最後補一個 `_`，裡面丟錯或回一個明顯的值。

⚠ tuple 模式是「前綴」比對，不是長度相符。

你會以為 `[a b]` 只配剛好兩格的值。其實值比模式長，照樣算中：

```janet
(match [1 2 3] [a b] :two [a b c] :three)   # => :two
(match [1 2 3] [] :empty)                   # => :empty
```

第一行值有三格，第一個模式 `[a b]` 就中了，回 `:two`，根本輪不到 `[a b c]`。第二行更誇張，空模式 `[]` 什麼 tuple 都吃。

因為 tuple 模式只檢查「模式列出來的那幾格存不存在、相不相等」，不檢查總長度。比 `[a b]` 時，它看第 0、1 格在不在，在就中，第 2 格它不看。反過來，值比模式短就真的不中，`(match [1] [a b] :two _ :other)` 會回 `:other`。

解法有兩個。第一，模式由長排到短，長的先試：

```janet
(match [1 2 3] [a b c] :three [a b] :two)   # => :three
```

第二，真要「剛好 N 格」，用守衛把長度講明白：

```janet
(match [1 2]   (t (and (indexed? t) (= 2 (length t)))) :exactly-two _ :other)   # => :exactly-two
(match [1 2 3] (t (and (indexed? t) (= 2 (length t)))) :exactly-two _ :other)   # => :other
```

`indexed?` 檢查它是 tuple 或 array，`(= 2 (length t))` 檢查剛好兩格。兩個都成立才算中。

這個坑最麻煩的是不會有任何錯誤訊息。排錯順序的後果只是走錯分支，要靠你看結果才發現。

## 收尾：一個小直譯器

把前面的東西湊起來。假設你收到一串指令，有的是 tuple、有的是字典：

```janet
(defn run [cmd]
  (match cmd
    [:add a b]            (+ a b)
    [:neg x]              (- x)
    {:op "mul" :a a :b b} (* a b)
    _                     :unknown))

(map run [[:add 1 2] [:neg 5] {:op "mul" :a 2 :b 3} [:foo]])   # => @[3 -5 6 :unknown]
```

每種指令一行：左邊寫它的形狀，右邊寫要做什麼。認不得的指令落到 `_`。同樣的事用 `if` 加 `get` 寫，要先檢查型別、再檢查第 0 格、再一格一格拿值，會長好幾倍。這就是你讀 Janet 程式碼時到處看到 match 的原因：處理「好幾種形狀的資料」時，它最省字，也最好讀。

另外，如果你只想要「拿得到值才繼續」，不需要比形狀，Janet 還有 `when-let`、`if-let` 這一家，比 match 更輕，想更深那篇有講。

## 小練習

1. 寫 `(area shape)`：`[:square s]` 回 `s*s`，`[:rect w h]` 回 `w*h`，其他回 `:unknown`。`(area [:rect 2 3])` 要回 6。
2. 寫 `(greet user)`：值是有 `:name` 鍵的字典就回 `(string "hi " name)`，否則回 `"hi stranger"`。
3. 下面這段想分辨一格、兩格，卻永遠回 `:one`。修好它：`(match [1 2] [a] :one [a b] :two)`。

答案在 [examples/course/6-4.janet](../examples/course/6-4.janet) 最後。

## 想更深

- [docs/32 條件與模式比對](../docs/32-條件與模式比對.md)：把 if／cond／case／match 放在一起比怎麼挑，還有 `when-let` 家族綁多個名字時的短路行為。
- [docs/01c 解構與執行緒巨集](../docs/01c-解構與執行緒巨集.md)：解構的完整寫法，拿來對照 match 的模式很像但哪裡不同。

下一課：[7-1 · 錯誤怎麼丟怎麼接](7-1-錯誤怎麼丟怎麼接.md)
