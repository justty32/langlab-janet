# 串流（SSE）

[← 回 llm-http README](../README.md)｜相關：[https 與 curl](https-與-curl.md)

送 `stream: true`，伺服器一小塊一小塊推回來；`chat-stream` 每塊叫一次 `:on-delta`，
收完把片段**合成跟 `chat` 同形狀的回應**，所以 `reply-text`／`reply-finish-reason`／`reply-usage` 照用。

```janet
(llm/ask-stream cfg "用三句話介紹 Janet")          # 邊印邊收，收完補換行，回完整字串

(def res (llm/chat-stream cfg @[@{:role "user" :content "…"}]
                          :on-delta (fn [t] (prin t) (flush))))
(llm/reply-text res)            # 片段接起來的完整答案
(llm/reply-finish-reason res)   # "stop"／"length"／"tool_calls"
(llm/reply-usage res)           # 最後那塊帶的 usage（要伺服器支援 stream_options，見下）
(res :chunks)                   # 這次收了幾個 SSE 事件
```

```sh
./build/llm-http --stream local "用三句話介紹 Janet"     # CLI；⚠ 不能跟 --tools 一起用
```

實測（另一個行程起一台假 SSE 伺服器，每 50 ms 推一塊；答案是一塊塊印出來的，最後補換行）：

```
$ janet modules/llm-http/main.janet --stream --url http://127.0.0.1:45771/v1/chat/completions -m demo fake "介紹 Janet"
Janet 是一個 Lisp 方言。
```

## 傳輸選了哪條、為什麼

| `:url` | 傳輸 | 為什麼不用 spork/http 的 `http/request` |
|--------|------|------|
| `http://` | `stream-http.janet`：`net/connect` ＋ 手寫最小 HTTP/1.1，自己解 chunked | 實測看它的 `read-body`：content-type 是 `text/event-stream` 時**只 `read-until "\n\n"`**——讀到第一個事件就回——而且 `request` 在 `defer` 裡把連線關了。借它的 `url-grammar` 與 `read-response`（解狀態列與 header），body 自己讀 |
| `https://` 或 `:transport :curl` | `stream-curl.janet`：`curl -N` 逐段讀 stdout | spork 沒 TLS；`-N` 讓 curl 收到多少吐多少（預設會攢 4 KB） |

兩條傳輸只負責「一段段交出 bytes」，切行、解 `data:`、合併片段是同一套（`sse.janet`），
所以兩條長出來的回應一樣——`test/llm-http-stream.janet` 拿同一台假伺服器把兩條都跑一遍。

## 合併規則（實測用假伺服器驗過）

假伺服器把一則回覆切成這些事件推回來（含 `: ping` 註解行與分成三塊的 `tool_calls`）：

```
data: {"choices":[{"index":0,"delta":{"content":"你"}}]}
: ping
data: {"choices":[{"index":0,"delta":{"content":"好"}}]}
data: {"choices":[{"index":0,"delta":{},"finish_reason":"stop"}]}
data: {"choices":[],"usage":{"prompt_tokens":3,"completion_tokens":2,"total_tokens":5}}
data: [DONE]
```

- `content` 片段依序接起來；`on-delta` 收到 `"你"`、`"好"` 兩次。
- `tool_calls` 依 **`index`** 分桶：`id`／`name` 通常第一塊才有，`arguments` 是切成好幾塊的 JSON 字串要一路接。
  `"get_"`＋`"weather"` 接成 `"get_weather"`，`{"city":`＋`"台北"}` 接成 `{"city":"台北"}`。
- `finish_reason` 與 `usage` 取**最後一次出現**的；只有 `tool_calls` 沒有文字時 `content` 是 `nil`（跟 OpenAI 一樣）。
- `event:`／`: ping`／空行都不是資料，一律略過；只認 `data:` 開頭的行；`[DONE]` 之後不再處理。

## ⚠ 幾個坑

- **usage 要另外要**：OpenAI 相容端點只有送 `stream_options: {include_usage: true}` 才會在最後多推一塊 usage。
  `chat-stream` 預設會送；伺服器不認的話用 `:include-usage false` 關掉。
- **串流時 HTTP 200 一樣不代表講完**：被 `max_tokens` 截斷 `finish_reason` 還是 `"length"`，CLI 會在 stderr 警告。
- **非 2xx 不是 SSE**：伺服器回一份 JSON 錯誤。兩條傳輸都會把它讀完再丟中文錯誤，訊息帶狀態碼與原文：
  `HTTP 429（http://127.0.0.1:45731/err）：{"error":"太多了"}`。
- **`--stream` 與 `--tools` 不能一起用**：tool loop 要拿到完整的 `tool_calls` 才能執行，串流版的 loop 沒做。
  函式庫這邊可以自己用 `chat-stream` 的回應（形狀跟 `chat` 一樣）接進歷史再繼續。
- **Anthropic 那條也能串流**：事件形狀不同（`message_start`／`content_block_delta`…），由 `stream-anthropic.janet`
  合成 Anthropic 回應再走同一個 `from-anthropic`，見 [Anthropic 原生](anthropic-原生.md)。

能跑的示範 → [`../../examples/llm-http/09-stream.janet`](../../../examples/llm-http/09-stream.janet)。
