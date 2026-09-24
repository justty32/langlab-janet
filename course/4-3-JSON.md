# 4-3 · JSON

JSON 是跟外界交換資料的通用格式：設定檔、API 回應、存檔都是它。這課教你把 Janet 的資料變成 JSON 文字、把 JSON 文字變回 Janet 的資料，還有三個會讓你以為「資料不見了」的地方。

## 這是什麼、為什麼

JSON 長這樣：`{"name":"Bob","ids":[1,2,3]}`。你會發現它跟 Janet 的 struct、tuple 幾乎一模一樣，只差鍵的寫法（JSON 用 `"name"`，Janet 習慣用 `:name`）。所以在 Janet 裡處理 JSON 特別順：資料在腦子裡不用換形狀。

轉換的工具在 `spork/json` 裡。spork 是 Janet 官方的擴充函式庫，1-1 裝環境時已經裝好了。用之前先 `(import spork/json)`，之後函式就以 `json/` 開頭。

兩個方向、兩個函式：

- `json/encode`：Janet 資料變 JSON 文字。
- `json/decode`：JSON 文字變 Janet 資料。

## 動手

### encode：資料變文字

```janet
(import spork/json)
(json/encode {:name "Bob" :n 3})   # => @"{\"name\":\"Bob\",\"n\":3}"
(print (json/encode {:name "Bob" :n 3}))
# 印出：{"name":"Bob","n":3}
```

回傳的是一個 buffer（前面有 `@`），內容就是 JSON 文字；印出來看比較清楚。要字串就 `(string (json/encode ...))`。

要給人看的縮排版，多給兩個參數：縮排用什麼、換行用什麼。

```janet
(import spork/json)
(print (json/encode {:name "Bob" :ids [1 2]} "  " "\n"))
# 印出：
# {
#   "name": "Bob",
#   "ids": [
#     1,
#     2
#   ]
# }
```

struct 跟 table 都變 object，tuple 跟 array 都變 array，keyword 當值會變字串：

```janet
(import spork/json)
(json/encode @{:list @[1 2]})   # => @"{\"list\":[1,2]}"
(json/encode {:a :k})   # => @"{\"a\":\"k\"}"
(protect (json/encode {:f (fn [] 1)}))   # => (false "encode error: type not supported")
```

函式這種 JSON 沒有的東西塞進去會報錯。

### decode：文字變資料

```janet
(import spork/json)
(def d (json/decode "{\"name\":\"Bob\",\"tags\":[\"a\",\"b\"]}" true))
(get d :name)   # => "Bob"
(get-in d [:tags 1])   # => "b"
(type d)   # => :table
```

解出來是 table（object）跟 array，都是可變的，3-2 的 `get`、`get-in`、`put` 全部能用。第二個參數 `true` 的意思是「把鍵轉成 keyword」，下面的坑會講為什麼幾乎一定要給。

壞掉的 JSON 會拋錯，錯誤訊息會說在第幾個字：

```janet
(import spork/json)
(protect (json/decode "{bad"))   # => (false "decode error at position 1: expected json string")
```

要接不可信的輸入，用 7-1 的 `try` 包起來。

### null 跟 nil

JSON 有 `null`，Janet 有 `nil`，但兩邊不是一對一。encode 這邊，值是 nil 的鍵會整個消失（3-2 講過 table 放 nil 就等於刪掉），想送 `null` 得放 keyword `:null`：

```janet
(import spork/json)
(json/encode {:a nil :b 1})   # => @"{\"b\":1}"
(json/encode {:a :null})   # => @"{\"a\":null}"
```

decode 這邊，預設把 `null` 解成 `:null`，第三個參數給 `true` 才會變 nil：

```janet
(import spork/json)
(json/decode "null")   # => :null
(json/decode "null" true true)   # => nil
(get (json/decode "{\"a\":1,\"b\":null}" true) :b)   # => :null
(json/decode "{\"a\":1,\"b\":null}" true true)   # => @{:a 1}
```

看最後一行：開了 nil 之後 `:b` 這個鍵直接不見了，同一個原因。所以要分得出「鍵存在但是空」跟「鍵根本不在」，就用預設的 `:null`，自己判斷 `(= v :null)`。

### 存到檔案、讀回來

```janet
(import spork/json)
(spit "cfg.json" (json/encode @{:debug true} "  " "\n"))
(def back (json/decode (slurp "cfg.json") true))
(get back :debug)   # => true
```

`spit` 寫整個檔、`slurp` 讀整個檔（8-1 細講）。設定檔的讀寫就這四行。

## 你會踩的坑

⚠ 忘了給 `true`，取值全部變 nil。
你會以為 `(json/decode s)` 之後 `(get d :name)` 拿得到值。其實拿到 nil，而且沒有任何錯誤。因為沒給第二個參數時，鍵是字串 `"name"`，不是 keyword `:name`，兩者在 3-3 講過永遠不相等，每一層都查不到。遇到「明明有資料卻全是 nil」，先檢查這個 `true`。

```janet
(import spork/json)
(def d (json/decode "{\"name\":\"Bob\"}"))   # => @{"name" "Bob"}
(get d :name)   # => nil
(get d "name")   # => "Bob"
```

⚠ 中文變成 `晴` 不是壞掉。
你會以為 `(json/encode {:cond "晴"})` 印出 `{"cond":"晴"}`。其實印出 `{"cond":"\u6674"}`。因為 spork/json 把所有非 ASCII 的字都逃逸成 `\uXXXX`，這是合法 JSON，任何一端解回來都是「晴」。要確認內容對不對，解回來看，不要盯著 encode 的輸出。

```janet
(import spork/json)
(print (json/encode {:cond "晴"}))
# 印出：{"cond":"\u6674"}
(print (get (json/decode (json/encode {:cond "晴"}) true) :cond))
# 印出：晴
```

⚠ encode 回的是 buffer，不是字串。
你會以為 `(= (json/encode {:a 1}) "{\"a\":1}")` 是 true。其實是 false。因為回傳的是 buffer，4-1 講過 buffer 跟字串用 `=` 比永遠不等。要比、要當鍵，先 `(string ...)`。

## 小練習

1. 把 `@{:title "買牛奶" :done false}` 編成縮排的 JSON 印出來。
2. 把 `"[{\"n\":\"A\"},{\"n\":\"B\"}]"` 解開，印出第二個元素的 `:n`。
3. 把 `"{\"a\":null}"` 用預設方式解開，判斷 `:a` 是不是 `:null`，是就印 `a 是空的`。

## 想更深

- [docs/03 JSON](../docs/03-json.md)：多講了 encode 第四個參數（附加到既有 buffer）、`update-in` 改巢狀值、小抄表。
- [docs/17 用 spork/http 打 API](../docs/17-用-spork-http-打-api.md)：拿 JSON 真的去打網路 API。

下一課：[5-1 · 條件](5-1-條件.md)
