# 10-1 · fiber：可以暫停再繼續的函式

一般函式呼叫下去就得跑到底才回來。這課教 fiber（可以跑到一半停下來、把值交出去、之後再從停的地方繼續的函式）。學完你能自己寫一個「要一個給一個」的產生器，也會知道前面學過的 `try` 底層就是它。

## 這是什麼、為什麼

想像你寫一個函式要吐出一百萬個數字。用回傳值只能一次全部算完塞進 array 再回來，記憶體跟時間都先付清。如果能「算出一個就先交出去，等對方要下一個時再繼續算」，就不用預付了。這件事 Python 叫 generator，JS 叫 `function*`，Janet 叫 fiber。

Janet 的 fiber 比 generator 再多一點：它是一段獨立的執行流，有自己的呼叫堆疊，暫停時整個堆疊都保留著。所以它不只能當產生器，也拿來做錯誤處理（下面會看到）和非同步（下一課）。三件事，同一套機制。

三個動作記住就好：`fiber/new` 把函式包成 fiber、`resume` 推它往前跑、`yield` 在 fiber 裡面喊「先停，這個值交出去」。

## 動手：建、推、停

```janet
(def f (fiber/new (fn [] (yield 1) (yield 2) (yield 3) :done)))
(fiber/status f)   # => :new
(resume f)   # => 1
(resume f)   # => 2
(resume f)   # => 3
(fiber/status f)   # => :pending
(resume f)   # => :done
(fiber/status f)   # => :dead
```

`fiber/new` 只是包起來，還沒動，狀態是 `:new`。第一次 `resume` 跑到第一個 `yield` 就停，把 `1` 當 `resume` 的回傳值交出來。再 `resume` 就從剛才停的地方接著跑。停在 `yield` 上時狀態是 `:pending`（暫停中）。最後一次 `resume` 跑完整個函式，函式的回傳值 `:done` 也從 `resume` 拿到，狀態變 `:dead`（跑完了）。

跑完再推會炸：

```janet
(def f (fiber/new (fn [] (yield 1))))
(resume f)   # => 1
(resume f)   # => nil
(protect (resume f))   # => (false "cannot resume fiber with status :dead")
```

第二次 `resume` 讓函式跑完（沒有回傳值所以是 `nil`），第三次就是推一個死掉的 fiber，錯誤訊息直接說 status 是 `:dead`。

## 動手：當產生器走訪

fiber 可以直接丟給 `each`，每個 `yield` 的值就是一個元素：

```janet
(def squares (fiber/new (fn [] (for i 0 5 (yield (* i i))))))
(each x squares (prin x " "))
# 印出：0 1 4 9 16
```

重點是惰性：`(* i i)` 是走到那一格才算的。所以你可以寫無限產生器，反正對方要幾個才算幾個：

```janet
(def nums (fiber/new (fn [] (var n 0) (forever (yield (++ n))))))
(take 3 nums)   # => @[1 2 3]
(resume nums)   # => 4
```

`forever` 是永遠不停的迴圈，但每圈都在 `yield` 停下來等人推，所以不會卡住程式。`take 3` 只推三次就走人，之後再 `resume` 就拿到第四個。

## 動手：resume 也能把值送進去

`(yield x)` 本身也有回傳值，就是下一次 `resume` 塞進來的第二個參數：

```janet
(def echo (fiber/new (fn [] (def got (yield :ready)) (yield (string "got " got)))))
(resume echo)   # => :ready
(resume echo "hello")   # => "got hello"
```

第一次 `resume` 拿到 `:ready`，fiber 停在 `(yield :ready)` 那裡。第二次 `resume` 帶著 `"hello"` 進去，那個 `yield` 就回傳 `"hello"`，綁給 `got`。這是雙向溝通：外面推值進去、裡面交值出來。

## 動手：try 其實就是 fiber

7-1 學過的 `try`、`protect` 底層都是「開一個 fiber 跑 body，攔住 error 訊號」。`fiber/new` 的第二個參數就是要攔哪些訊號，`:e` 是攔 error：

```janet
(def e (fiber/new (fn [] (error "boom")) :e))
(resume e)   # => "boom"
(fiber/status e)   # => :error
```

fiber 裡面 `error` 了，但外面沒有炸，`resume` 只是把錯誤訊息當值交出來，狀態變 `:error`。`try` 就是這件事包成好看的語法。常見的遮罩還有 `:y`（攔 yield）跟 `:a`（全攔），平常用不到，知道有這回事就好。

## 你會踩的坑

⚠ 你會以為 `each` 走過一個 fiber，之後還能再走一次。其實是第二次什麼都不會印。因為 fiber 是狀態機，走完就 `:dead`，`each` 看到 dead 就當作沒東西；要再走一遍得再 `fiber/new` 一個。

⚠ 你會以為 `(fiber/new f)` 寫下去函式就開始跑。其實是一步都沒動，狀態是 `:new`。因為 fiber 是「等人推才動」的，第一步永遠是 `resume`（或交給 `each`／`take` 幫你推）。

## 小練習

1. 寫一個 fiber 依序 yield 費氏數列，用 `take 8` 拿前八個。
2. 寫一個 fiber，`resume` 送進一個數字就 yield 它的兩倍，連續送三個試試。

解答在範例檔最後。

## 想更深

- [docs/09 fiber](../docs/09-fiber.md)：多講了訊號遮罩的完整用法，跟 ev 的關係。
- [docs/20 錯誤處理與資源管理](../docs/20-錯誤處理與資源管理.md)：多講了 try／protect／defer 在實務上怎麼選。

範例檔：`janet examples/course/10-1.janet`

下一課：[10-2 · ev 非同步](10-2-ev-非同步.md)
