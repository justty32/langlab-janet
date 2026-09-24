# 7-1b · 往上丟、回 nil、常見的坑

接續 [7-1](7-1-錯誤怎麼丟怎麼接.md)。前半講了怎麼丟、怎麼接；這半講「接到了但不想處理」怎麼辦、自己寫函式時該回 `nil` 還是拋錯，最後是三個新手一定會踩的坑。

## 接到但不想處理：propagate

catch 那段的方括號可以多綁一個名字 `f`，它是出錯當下的執行現場（Janet 叫 fiber，10-1 會講）。`(propagate e f)` 把錯誤原樣往外丟，而且保留原本「炸在哪裡」的資訊：

```janet
(protect
  (try
    (error {:code 500})
    ([e f] (if (= 500 (e :code)) (propagate e f) :handled))))
# => (false {:code 500})
```

只有 500 才往上丟，其他錯誤就地處理回 `:handled`。這就是「只接自己認得的錯誤」的寫法。

想在往上丟之前補一句說明也行，直接再 `error` 一次：

```janet
(protect
  (try (slurp "config.json")
    ([e] (errorf "startup failed: %s" e))))
# => (false "startup failed: could not open file config.json")
```

這樣外層看到的不是一句孤零零的 `could not open file`，而是知道是啟動時讀設定檔出的事。

## 什麼時候回 nil，什麼時候拋錯

Janet 內建函式自己分成兩派，照著抄就好：

- 「查不到很正常」的事回 `nil`。`(get t :missing)`、`(string/find "z" "abc")`、`(os/stat "nope")`、`(scan-number "abc")` 都是這派。
- 「這件事本來就該成功」的事拋錯。`(slurp "nope.txt")` 讀不到檔就炸。

```janet
(string/find "z" "abc")   # => nil
(scan-number "abc")       # => nil
(protect (slurp "nope.txt"))   # => (false "could not open file nope.txt")
```

回 `nil` 的好處是呼叫端直接接 `if`，不用開 try。拋錯的好處是壞掉時不會默默帶著 `nil` 跑很遠才炸。自己寫函式時照這個原則挑一邊，別兩邊都做。

## 你會踩的坑

⚠ 你會以為：接到的錯誤一定是字串，可以直接 `(string "失敗：" e)` 拼起來印。其實是：你丟什麼它就是什麼，丟 table 就接到 table，拼字串會得到 `<table 0x...>` 這種東西。因為 `error` 不會幫你轉型，它只是把值原樣送出去。要印就用 `%j` 或 `pp`。

```janet
(try (error @{:code 404}) ([e] (string/has-prefix? "<table" (string e))))   # => true
```

⚠ 你會以為：`try` 能接住所有錯誤，包括參數個數寫錯。其實是：參數個數錯是 compile error（編譯期錯誤），在程式開始跑之前就被擋下來，`try` 根本沒機會執行。因為 `try` 是執行期的機制，而 Janet 在編譯每個 form 時就會核對已知函式的參數個數。這種錯長怎樣、怎麼分辨，7-3 會講。

⚠ 你會以為：`assert` 只是除錯用，正式版會被拿掉。其實是：Janet 沒有「正式版關掉 assert」這回事，它永遠會跑。因為 Janet 沒有 C 的 `NDEBUG` 那種編譯開關，`assert` 就是一般函式呼叫。所以它適合當正式的前提檢查，但別放在每秒跑幾萬次的迴圈裡做很貴的檢查。

## 小練習

1. 寫 `(safe-div a b)`：`b` 是 0 時丟一個帶 `:code :div-by-zero` 與 `:a` 欄位的 struct，否則回 `(/ a b)`。用 `try` 接住並印出 `:code`。
2. 寫 `(parse-age s)`：用 `scan-number` 把字串轉數字；轉不出來或不在 0 到 150 之間就用 `errorf` 丟出含原字串的訊息。用 `protect` 各測一個好的跟壞的輸入。
3. 把練習 2 改成「回 nil」版本 `(parse-age? s)`，想一下哪個版本的呼叫端寫起來比較順。

解答在 `examples/course/7-1.janet` 最後。

## 想更深

- [docs/20 錯誤處理與資源管理](../docs/20-錯誤處理與資源管理.md)：多講了「三者怎麼選」的對照表，以及 catch 拿到 fiber 之後怎麼印堆疊。
- [docs/09 fiber](../docs/09-fiber.md)：`try` 底層其實是用 fiber 攔信號做的，那篇講原理。
- [docs/32 條件與模式比對](../docs/32-條件與模式比對.md)：丟 struct 之後，用 `match` 依 `:code` 分流的寫法。

下一課：[7-2 · 資源收尾：defer 與 with](7-2-資源收尾-defer-with.md)
