# 7-2b · defer 與 with 的坑

接續 [7-2](7-2-資源收尾-defer-with.md)。前半教了怎麼用，這半講四個會讓你「明明寫了收尾卻沒收到」的地方，最後是練習。

## 你會踩的坑

⚠ 你會以為：照 Go 的習慣，`defer` 後面接的是「主要的事」，收尾寫在別處。其實是：Janet 的 `defer` 第一個參數就是收尾動作，從第二個開始才是 body。因為它是巨集，要先拿到收尾動作才能把後面所有東西包起來。寫反了不會報錯，只是你的「收尾」變成先跑，「主要的事」變成收尾，結果整個顛倒。

```janet
(def log @[])
(defer (array/push log :cleanup) (array/push log :body))
log   # => @[:body :cleanup]
```

⚠ 你會以為：`with` 什麼東西都能收。其實是：它預設呼叫 `:close`，沒有這個方法就在離開時炸給你看。因為 `with` 只是「離開時呼叫 `(:close x)`」的簡寫，它不知道你的東西該怎麼關。

```janet
(protect (with [r @{}] :ok))
# 印出類似：(false "unknown method :close invoked on <table 0x...>")
```

看到 `unknown method :close` 就是這個坑：要嘛給它有 `:close` 的東西，要嘛在第三個位置放自己的收尾函式。

⚠ 你會以為：body 炸了、收尾也炸了，你會看到 body 的錯誤。其實是：你只會看到收尾的錯誤，body 那個被蓋掉。因為收尾是在錯誤往外傳的路上跑的，收尾自己再丟一個錯，後丟的把先丟的換掉了。

```janet
(protect (defer (error "cleanup boom") (error "body boom")))
# => (false "cleanup boom")
```

所以收尾動作要保守，別在裡面做會炸的事；真的可能炸就在收尾裡自己 `protect`。

⚠ 你會以為：把檔案 handle 放進一個 table 存著，用完 Janet 會自動幫你關。其實是：不會，它會一直開著直到程式結束。因為 Janet 只有 GC 沒有解構子，物件被回收的時機你控制不了，而且回收也不保證關檔。每個 handle 都要有一個明確的 `with` 區塊當主人，決定它什麼時候關。

## 小練習

1. 寫 `(忙一下 f)`：進去時把 `var 狀態` 設成 `:busy`，跑 `(f)`，離開時設回 `:idle`。用一個會炸的 `f` 試，確認炸完之後 `狀態` 還是 `:idle`。
2. 做一個假資源：`(defn 開 [])` 回一個帶 `:close` 方法的 table，`:close` 被呼叫時把計數器加一。用 `with` 開三次，其中一次在 body 裡丟錯（用 `protect` 包），最後確認計數器是 3。
3. 巢狀兩層 `with`，各開一個假資源 A 與 B，`:close` 時印自己的名字。跑一次，觀察關閉順序是 B 先 A 後。

解答在 `examples/course/7-2.janet` 最後。

## 想更深

- [docs/20b 資源管理](../docs/20b-資源管理.md)：多講了 `with` 等於「局部作用域版的 RAII」這個對照，給從 C++ 過來的人看。
- [docs/19 檔案與檔案系統](../docs/19-檔案與檔案系統.md)：`with` 配 `file/open` 的各種模式，下一單元 8-1 也會用到。
- [docs/09 fiber](../docs/09-fiber.md)：`with` 展開後其實是開一個 fiber 跑 body，錯誤怎麼被攔下來再 `propagate` 出去，那篇有原理。

下一課：[7-3 · 讀錯誤訊息](7-3-讀錯誤訊息.md)
