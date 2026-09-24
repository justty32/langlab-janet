# 7-3b · 尾呼叫與 trace 的坑

接續 [7-3](7-3-讀錯誤訊息.md)。這半講 trace 裡最會誤導人的一件事：**有些函式明明被呼叫了，卻不會出現在 trace 裡**。再講怎麼在程式裡自己印 trace，最後是坑與練習。

## 尾呼叫會吃掉一層

把這段存成 `tail.janet`：

```
(defn 第三層 [x] (error "最裡面炸了"))
(defn 第二層 [x] (+ 1 (第三層 x)))
(defn 第一層 [x] (第二層 x))
(第一層 42)
```

```
error: 最裡面炸了
  in 第三層 [tail.janet] on line 1, column 21
  in 第二層 [tail.janet] (tail call) on line 2, column 26
  in thunk [tail.janet] (tail call) on line 4, column 1
```

`第一層` 不見了。它明明被呼叫了（第 4 行），trace 卻直接從 `第二層` 跳到 `thunk`。

原因：`(defn 第一層 [x] (第二層 x))` 裡，呼叫 `第二層` 是 `第一層` 做的**最後一件事**，回來之後不用再算什麼。這叫尾呼叫（tail call）。Janet 碰到尾呼叫會把 `第一層` 的位置直接讓給 `第二層`，不留痕跡。好處是遞迴再深也不會爆堆疊，代價是 trace 少一層。

行尾的 `(tail call)` 標記是線索：它表示**這一格自己做了尾呼叫**，所以它跟下一格之間可能藏著看不到的層。`第二層` 那行有標記，因為 `第二層` 是被 `第一層` 尾呼叫的。

想讓 `第一層` 出現，讓呼叫不在尾位置就好，例如回來之後多做一件事：

```
(defn 第一層 [x] (do (第二層 x) nil))
```

```
error: 最裡面炸了
  in 第三層 [notail.janet] on line 1, column 21
  in 第二層 [notail.janet] on line 2, column 26
  in 第一層 [notail.janet] on line 3, column 25
  in thunk [notail.janet] (tail call) on line 4, column 1
```

三層全在。除錯時卡在「某層去哪了」就用這招。

## 在程式裡自己印 trace

7-1b 說過 catch 可以多綁一個 `f`（出錯當下的 fiber）。`debug/stacktrace` 拿它把整串 trace 印出來，程式不用停：

```
(defn 裡 [x] (error "壞了"))
(defn 外 [x] (+ 1 (裡 x)))
(try (外 1) ([e f] (debug/stacktrace f e "")))
(print "程式繼續跑")
```

```
error: 壞了
  in 裡 [st.janet] on line 1, column 15
  in 外 [st.janet] (tail call) on line 2, column 20
程式繼續跑
```

⚠ 第三個參數 `""` 不能省。省掉的話它只印 `in ...` 那幾行，不印 `error:` 那行。

## 你會踩的坑

⚠ 你會以為：trace 跟 Python 一樣，最後一行才是炸掉的地方。其實是：Janet 第一行 `in` 就是最裡面，越往下越外層。因為 Janet 從出錯的那一格開始往外列，跟 gdb 的 `bt` 同一個方向。看反了會去改最外層那行，白忙一場。

⚠ 你會以為：函式沒出現在 trace 裡就是沒被呼叫。其實是：它很可能被呼叫了，只是做了尾呼叫，位置被下一層接手。因為尾呼叫最佳化不保留那一層。看到 `(tail call)` 標記就要想到中間可能有隱藏的層。

⚠ 你會以為：`expected string, symbol, keyword, array, tuple, table, struct or buffer, got 1` 是在說某個參數型別錯。其實是：多半是你呼叫了一個 `nil`。因為 Janet 裡資料結構本身可以當函式呼叫（`("abc" 1)` 等於 `(get "abc" 1)`），所以 `(f 1)` 在 `f` 是 `nil` 時被當成「拿 1 去索引」，它抱怨的是 `1` 不能被索引。

```janet
(def f nil)
(protect (f 1))     # => (false "expected string, symbol, keyword, array, tuple, table, struct or buffer, got 1")
(protect (f 1 2))   # => (false "nil called with 2 arguments, possibly expected 1")
```

兩個以上參數就沒有歧義，訊息才變好懂。記法：訊息在講一個你沒預期的型別，先確認你呼叫的東西是不是 `nil`。

⚠ 你會以為：trace 會印在你的 `print` 之間，照程式順序。其實是：trace 走 stderr，`print` 走 stdout，兩條管線各自緩衝，重導到檔案時 trace 常常整包跑到最前面。因為 stderr 不緩衝、stdout 會。要對照順序就別重導，或把 `print` 換成 `eprint`（印到 stderr）。

## 小練習

1. 下面這段 trace（`janet app.janet` 真的跑出來的）是哪個函式炸的？你的程式裡最裡面那層在第幾行？哪幾行可以直接跳過？
   ```
   error: could not open file data.csv
     in slurp [boot.janet] on line 1891, column 13
     in 載入 [app.janet] on line 2, column 15
     in main [app.janet] (tail call) on line 6, column 12
     in run-main [boot.janet] on line 4684, column 16
     in cli-main [boot.janet] on line 4904, column 17
   ```
2. 修好 7-3 的 `crash.janet`：在 `讀分數` 開頭加 `assert`，讓錯誤訊息直接說出是哪一筆資料少了 `:score`。
3. 把 `tail.janet` 的 `第二層` 也改成尾呼叫，跑一次看 trace 剩幾行。

解答在 `examples/course/7-3.janet` 最後。

## 想更深

- [docs/34 讀錯誤訊息與除錯](../docs/34-讀錯誤訊息.md)：多講了 `trace`／`untrace`（不改程式碼看某個函式被怎麼呼叫）跟更長的訊息對照表。
- [docs/33 函式參數與閉包](../docs/33-函式參數與閉包.md)：為什麼參數個數是編譯期檢查，以及用 `apply` 繞過它時訊息會變成什麼。
- [docs/09 fiber](../docs/09-fiber.md)：`try` 的 `f` 到底是什麼、trace 為什麼還留在裡面。

下一課：[8-1 · 讀寫檔案](8-1-讀寫檔案.md)
