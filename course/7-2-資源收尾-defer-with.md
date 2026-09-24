# 7-2 · 資源收尾：defer 與 with

開了檔案要關、改了狀態要改回來、借了東西要還。麻煩的是中間一炸，程式直接跳走，你寫在後面的「關掉」那行根本沒跑到。這課教兩個工具：`defer` 讓一段收尾動作「離開區塊時一定跑」，`with` 專門處理「開了就一定關」。

## 這是什麼、為什麼

你可能用過 Python 的 `with` 或 `try/finally`、Go 的 `defer`、C++ 的解構子。它們解決同一件事：不管中間發生什麼，收尾一定要跑。

Janet 有垃圾回收（GC，程式自動幫你回收沒人用的記憶體），所以沒有解構子，你也不知道一個物件什麼時候會被回收。Janet 的做法是把收尾綁在**一段程式碼的範圍**上：這個區塊結束，收尾就跑。不管是正常跑完、中途 `break`、還是炸掉，都算「結束」。

`defer` 跟 `with` 都是巨集（一種語法，寫起來像呼叫函式，其實是在跑之前先把你的程式改寫成另一種形狀），10-4 會講巨集怎麼做出來，現在只要會用。

## 動手

### defer：離開這個區塊時一定跑

`defer` 的第一個參數是「離開時要做的事」，後面的全部是 body。回傳值是 body 最後一個式子的值：

```janet
(defer (print "收尾")
  (print "做事")
  (+ 1 2))
# 印出：做事
# 印出：收尾
# 回傳 3
```

注意順序：**收尾動作寫在前面，body 寫在後面**。這跟 Go 的 `defer` 相反，Go 是先寫 body 再 `defer`。Janet 這樣寫的理由是巨集要先看到收尾動作才好包住後面所有東西。

### body 炸了照樣收尾

這才是 `defer` 的重點。body 裡丟錯，收尾一樣跑，錯誤再繼續往外傳：

```janet
(protect (defer (print "cleanup ran") (error "body boom")))
# 印出：cleanup ran
# => (false "body boom")
```

`protect` 接到的還是 `body boom`，收尾動作沒有把錯誤吃掉，只是「順路」跑了一下。

### 迴圈 break 也算離開

```janet
(defn 找到就停 []
  (defer (print "收尾")
    (each i [1 2 3]
      (when (= i 2) (break))
      (print "i=" i))))
(找到就停)
# 印出：i=1
# 印出：收尾
```

### 巢狀 defer：後開的先收

```janet
(defer (print "外層收尾")
  (defer (print "內層收尾")
    (print "body")))
# 印出：body
# 印出：內層收尾
# 印出：外層收尾
```

先進去的最後才收，跟疊盤子一樣。你開了 A 再開 B，關的時候先關 B 再關 A。

### with：開了就一定關

`with` 是 `defer` 的特化版，專門給「有 `:close` 方法的東西」用。方括號裡寫「名字 怎麼取得」，離開時自動呼叫 `(:close 名字)`。用 `file/temp`（開一個用完就丟的暫存檔）示範：

```janet
(with [f (file/temp)]
  (file/write f "hello")
  (file/seek f :set 0)
  (file/read f :all))   # => @"hello"
```

離開 `with` 之後 `f` 已經被關掉了，再寫會炸：

```janet
(def f (file/temp))
(with [g f] (file/write g "x"))
(protect (file/write f "y"))   # => (false "file is closed")
```

### body 炸了，with 照樣關

```janet
(def 資源 @{:close (fn [self] (print "closed"))})
(protect (with [r 資源] (error "boom")))
# 印出：closed
# => (false "boom")
```

這裡自己做了一個有 `:close` 方法的 table 當假資源。`with` 不管 `r` 是什麼，離開時就呼叫它的 `:close`。

### 沒有 :close 的東西：第三個位置放收尾函式

```janet
(defn 關 [r] (print "custom close " (r :name)))
(with [r @{:name "db"} 關] (r :name))
# 印出：custom close db
# 回傳 "db"
```

`關` 會收到 `r` 當參數。什麼都不給的話 `with` 就找 `:close`，找不到就炸。

續篇講坑與練習：[7-2b · defer 與 with 的坑](7-2b-defer-與-with-的坑.md)
