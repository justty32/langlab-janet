# spork/http ・ 伺服端與底層零件

[← spork 索引](README.md)｜[← reference 索引](../README.md)

[docs/17](../../docs/17-用-spork-http-打-api.md) 教過 client 端怎麼打 API（`http/request` 的用法與兩個雷）。
這篇補**伺服端**與其餘沒教到的零件：怎麼起一台 server、router／middleware 怎麼串、cookie 怎麼解析、
以及底層的 PEG 文法與資料表。全部函式皆在**同一行程內**起 server 打 `127.0.0.1`（不碰外網）實測於 1.41.2。

## 伺服端

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `server` | `(server handler &opt host port)` | 包一層 `net/server`，起一台 HTTP 伺服器（預設 `0.0.0.0:8000`），立刻回傳、不卡住 |
| `server-handler` | `(server-handler conn handler)` | 單一連線的處理邏輯：讀一個 request、跑 `handler`、送回應、關連線 |
| `router` | `(router routes)` | 依 `:route`（不含 query string 的路徑）分派到 `routes` 表對應的 handler，沒對到查 `:default`，都沒有回 404 |
| `middleware` | `(middleware x)` | 把 function／數字（狀態碼）／字串／buffer 都轉成 `(req) -> 回應表` 的 handler |
| `logger` | `(logger nextmw)` | 包一層：印出 `方法 狀態 路徑 elapsed 耗時ms` |
| `cookies` | `(cookies nextmw)` | 包一層：把 `cookie` 標頭解析好放進 `(req :cookies)` |

```janet
(import spork/http)
(def routes
  (http/router
    {"/hi" (fn [req] {:status 200 :body "哈囉"})
     :default (fn [req] {:status 404 :body "沒這頁"})}))
(def handler (-> routes http/cookies http/logger))
(def server (http/server handler "127.0.0.1" 41999))

(def res1 (http/request "GET" "http://127.0.0.1:41999/hi"))
(print (res1 :status) " " (string (res1 :body)))   # => 200 哈囉
(def res2 (http/request "GET" "http://127.0.0.1:41999/nope"))
(print (res2 :status) " " (string (res2 :body)))   # => 404 沒這頁
(:close server)
# server 那端印：GET 200 /hi elapsed 0.001ms
#              GET 404 /nope elapsed 0.001ms
```

`middleware` 把不同型別都變成 handler：

```janet
(pp ((http/middleware 200) {}))         # => {:body "OK" :status 200}
(pp ((http/middleware "純文字") {}))     # => {:body "純文字" :status 200}
```

⚠ 數字要是 `http/status-messages` 裡有的碼（見下）才行，隨便給一個不存在的碼（例如 418）會直接 `error`。

`cookies` middleware 示範（`(req :cookies)` 是 table）：

```janet
(def h (http/cookies (fn [req] {:status 200 :body (string (req :cookies))})))
# 用瀏覽器送 Cookie: sid=abc123; theme=dark 這種標頭連進來，
# (req :cookies) 就是 @{"sid" "abc123" "theme" "dark"}
```

## 讀寫協定（通常不用自己呼叫，`server`／`request` 內部已經用了）

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `read-request` | `(read-request conn buf &opt no-query)` | 從連線讀一個 HTTP request 的 header，回傳 `:headers` `:method` `:path` `:route` `:query` 等 |
| `read-response` | `(read-response conn buf)` | 從連線讀一個 HTTP response 的 header，回傳 `:status` `:message` `:headers` 等 |
| `read-body` | `(read-body req)` | 依 `content-length`／`chunked`／SSE 讀出 body（buffer），沒有 body 回 `nil` |
| `send-response` | `(send-response conn response &opt buf)` | 把 `{:status :headers :body}` 寫回連線，`:body` 不是 bytes 就自動用 chunked 編碼 |
| `request` | `(request method url &keys {...})` | client 端發請求（docs/17 已教） |

## 資料表與 PEG 文法（底層零件，一般用不到，為了完整列出）

| 名字 | 型別 | 一句話 |
|---|---|---|
| `status-messages` | struct | HTTP 狀態碼 → 訊息字串的對照表（`(get http/status-messages 404)` => `"Not Found"`） |
| `url-grammar` | core/peg | 解析 URL 成 `[scheme host port path]` |
| `query-string-grammar` | core/peg | 解析 `?` 後面的 query string 成 table |
| `cookie-grammar` | core/peg | 解析 `Cookie:` 標頭成一串 key／value |
| `request-peg` / `response-peg` | core/peg | HTTP request／response 開頭那段的完整文法（`read-request`／`read-response` 用的底層） |

```janet
(pp (peg/match http/url-grammar "http://127.0.0.1:8000/a/b?x=1"))
# => @["http" "127.0.0.1" "8000" "/a/b?x=1"]     ⚠ path 含 query string，沒有另外切開
(pp (peg/match http/query-string-grammar "a=1&b=2&flag"))
# => @[@{"a" "1" "b" "2" "flag" true}]           沒給值的 key 對應到 true
(pp (peg/match http/cookie-grammar "sid=abc; theme=dark"))
# => @["sid" "abc" "theme" "dark"]               ⚠ 是攤平的 tuple，要自己 (apply table ...)
```

⚠ `url-grammar`／`http/request` 的路徑字元集只認 `a-z A-Z 0-9 ! $ % & ' ( ) * + , - . / : ; = ? @ ~ _`，
**不含中文、`{` `}` `"` `<` `>`**；`peg/match` 又不是強制吃完整個字串，超出字元集的部分會被靜靜截斷而不是
報錯——URL 裡如果手動塞 JSON 當 query string，多半會斷在第一個 `{`。要帶結構化資料走 query string 得自己
percent-encode（見 [http-框架與-rpc.md](http-框架與-rpc.md) 的 `httpf` GET 範例）。
