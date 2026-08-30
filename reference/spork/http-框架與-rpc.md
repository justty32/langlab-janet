# httpf／msg／rpc ・ 小型框架與訊息協定

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/httpf` 是「用 `defn` metadata 自動長出路由」的迷你框架（GET／POST／schema 驗證／JSON-HTML-JDN 都幫你轉）。
`spork/msg` 是最底層的「一則訊息 = 4-byte 長度前綴 + 內容」協定，`spork/rpc`（遠端程序呼叫：讓你像呼叫本機函式
一樣呼叫另一台機器上的函式）就是疊在 `msg` 上面的產物。全部範例都在**同一行程內**起 server 打
`127.0.0.1`（rpc 甚至可以真的建立 client／server 跑一輪，不用假裝）。全部函式皆以 `janet -e` 實測於 1.41.2。

## httpf

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `server` | `(server &opt parent)` | 建一個空的路由表狀態（`&opt parent` 可繼承另一個 server 當 blueprint） |
| `add-route` | `(add-route server path docstring schema handler &opt read-mime render-mime)` | 手動加一條路由 |
| `add-bindings-as-routes` | `(add-bindings-as-routes server &opt env)` | 掃目前環境裡所有帶 `:path` metadata 的 `defn`，自動註冊成路由 |
| `listen` | `(listen server-table &opt host port n-workers)` | 真的開始聽（阻塞），`n-workers` 給數字會開多個 worker fiber 平行處理 |
| `default-payload-wrapper` | `(default-payload-wrapper payload)` | 預設的回應外殼：包上 `:data` `:janet-version` `:time` 等欄位 |

```janet
(import spork/httpf)
(import spork/http)

(defn hello
  {:path "/hello" :doc "打招呼" :schema (props :name :string)}
  [req data]
  (string "哈囉, " (get data :name "世界")))

(def srv (httpf/server))
(httpf/add-bindings-as-routes srv)
(ev/spawn (httpf/listen srv "127.0.0.1" 42021))
(ev/sleep 0.05)

(def res (http/request "POST" "http://127.0.0.1:42021/hello"
                        :headers {"content-type" "application/json"}
                        :body (string `{"name":"小明"}`)))
(print (string (res :body)))
# => {
#      "data": "哈囉, 小明",
#      "time": 1788018265, "janet-version": "1.41.2", "janet-build": "0fea20c", "os": "linux"
#    }
```

⚠ `:schema` 是**沒有 quote 的 tuple**（`(props :name :string)`），不是 `'(props ...)`，
metadata 表本來就是資料字面量，多包一層 quote 會被當成 `(quote (props ...))` 送進 schema 驗證器直接炸掉。

GET 走的是 `?data=` 這個 query 參數，裡面放的是 **JDN**（Janet 自己的資料語法，`parse` 讀，不是 JSON），
而且 `http/request` 的路徑字元集不含 `{` `}` `"` 空白（見 [http-伺服端.md](http-伺服端.md) 的 ⚠），
要送結構化資料得自己 percent-encode：`?data=%7B:name%20:xiaoming%7D` 才會被 `(parse "{:name :xiaoming}")`
讀成 `{:name :xiaoming}`。也因此 GET 這條路多半只適合傳關鍵字／數字，字串型的資料建議走 POST。

`OPTIONS` 可以直接問一條路由的文件與 schema：
```janet
(http/request "OPTIONS" "http://127.0.0.1:42021/hello")
# body => <pre><code>{"doc": "(hello req data)\n\n", "schema": ["props","name","string"]}</code></pre>
```

## msg ・ 底層訊息協定

四位元組小端長度前綴 + payload，一個訊息一定完整送達或完全沒送達，不會攔腰截斷——這是 `rpc`、`netrepl`
都在用的地基。

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `make-send` | `(make-send stream &opt pack)` | 造一個 `(send msg)` 函式；`pack` 預設是 `string`（不會幫你序列化結構化資料） |
| `make-recv` | `(make-recv stream &opt unpack)` | 造一個 `(recv)` 函式，讀一則完整訊息；`unpack` 預設 `string` |
| `make-proto` | `(make-proto stream &opt pack unpack)` | 一次拿到 `[send recv]` 兩支函式 |

```janet
(import spork/msg)
(def [r w] (os/pipe))
# pack/unpack 用 marshal/unmarshal 才能送結構化資料（table、array...）
(def [send _] (msg/make-proto w marshal unmarshal))
(def [_ recv] (msg/make-proto r marshal unmarshal))
(send {:a 1 :b [1 2 3]})
(pp (recv))   # => {:a 1 :b (1 2 3)}
```

⚠ 預設 `pack` 是 `string`，對 table／struct 只會印出 `<struct 0x...>` 位址字串，**不是內容**——
送結構化資料一定要自己給 `marshal`／`json/encode` 之類的 `pack`，配對的 `unpack` 也要能還原（`unmarshal`／
`json/decode`）。

## rpc ・ 疊在 msg 上的遠端呼叫

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `server` | `(server functions &opt host port workers-per-connection)` | 起 RPC 伺服器，`functions` 是 `{"名字" 函式}`，函式第一個參數固定是 `functions` 本身 |
| `client` | `(client &opt host port name)` | 連上去，回傳一個 table：`(:方法名 client 參數...)` 直接呼叫遠端函式 |
| `default-host` | string | `"127.0.0.1"` |
| `default-port` | string | `"9366"` |

```janet
(import spork/rpc)
(def funcs {"add" (fn [self a b] (+ a b))
            "hello" (fn [self name] (string "哈囉, " name))})
(def server (rpc/server funcs "127.0.0.1" "42031"))
(def client (rpc/client "127.0.0.1" "42031" "test-client"))
(print (:add client 1 2))          # => 3
(print (:hello client "小明"))      # => 哈囉, 小明
(:close client)
(:close server)
```

呼叫一個伺服器沒宣告的方法，因為 client 端那個 key 根本不存在，會是一般的「找不到方法」錯誤，不是 rpc 自訂的：
`(:no-such-fn client 1)` => `error: unknown method :no-such-fn invoked on <table 0x...>`。
