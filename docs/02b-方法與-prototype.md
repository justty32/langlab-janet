# 02b · 方法呼叫語法與 prototype

[← 02 資料結構](02-資料結構.md)

上一篇講的是「四個容器怎麼裝東西」。這篇講**怎麼把行為也裝進去**——
這是 Janet 全部的 OOP，兩個小機制而已。

## 方法呼叫語法：keyword 放在呼叫位置

```janet
(def obj @{:greet (fn [self who] (string "hi " who))})
(:greet obj "you")     # => "hi you"
```

`(:key obj args…)` 等於「去 obj 裡拿 `:key` 這個函式，把 obj 自己當第一個參數傳進去」。
所以 handler 的第一個參數要留給 `self`——**忘了寫 self 是最常見的錯**：

```janet
(def bad @{:inc (fn [n] (+ n 1))})
(:inc bad 5)     # ✗ error: called with 2 arguments, expected 1
                 #   因為實際傳進去的是 (bad 5) 兩個參數
```

檔案、socket、子行程都吃這套：`(:read f :all)`、`(:close conn)`、`(:write (p :in) s)`。

### ⚠ `(:port cfg)` **不是**取值，而且失敗時靜默回 nil

從 Clojure 過來的人會寫 `(:port cfg)` 當作「取出 `:port`」——**在 Janet 這是錯的**：

```janet
(def cfg {:port 4000})
(cfg :port)       # => 4000    ✓ 取值是把「鍵」放呼叫位置
(get cfg :port)   # => 4000    ✓
(:port cfg)       # => nil     ⚠ 不報錯，就是 nil
```

因為 `(:k obj)` 是**方法呼叫**，展開成 `((get obj :k) obj)`：

```
(:port cfg) → ((get cfg :port) cfg) → (4000 cfg) → (get cfg 4000) → nil
```

`4000` 被放到呼叫位置，於是變成「用 4000 當鍵去索引 cfg」，當然找不到。
**整條鏈沒有一步會報錯**，所以這個 bug 會安安靜靜地流到很遠的地方
（怎麼追這種錯見 [34 讀錯誤訊息](34-讀錯誤訊息.md)）。

> 記法：**`(集合 鍵)` 取值，`(:鍵 物件)` 呼叫方法。** 值剛好是函式時後者才如你所願。

## prototype：Janet 的「繼承」

table 可以指定一張 prototype，查不到的 key 就往上找。**這就是 Janet 全部的 OOP**——
沒有 class 關鍵字；`(curenv)` 的環境繼承、模組、`make-env` 用的也都是同一個機制。
⚠ `(get t k)` 會走 prototype 鏈；只想看**自己這層**用 `(table/rawget t k)`。

怎麼拿它做出類別效果、三個一定會踩的陷阱、以及配合 `with` 當 RAII
→ **[22 原型與方法](22-原型與方法.md)**。


## 可跑範例

`janet examples/data-structures.janet`——最後兩節就是方法呼叫語法，
包含「忘了寫 self」的真實錯誤訊息與上面那個靜默 nil 的完整因果鏈。

下一步：[03-json.md](03-json.md)。
