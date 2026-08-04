# 17 · 用 spork/http 當 client 打 API

[03 JSON](03-json.md) 講怎麼把資料轉成 JSON，這篇講**怎麼把它送出去、怎麼把回來的東西當真**。
可跑的範例：[`../snippets/http-local/`](../snippets/http-local/main.janet)。
真的拿去用的成品：[`../modules/llm-http/`](../modules/llm-http/README.md)。

```janet
(import spork/http)
(import spork/json)
```

## GET 與 POST

```janet
(http/request "GET" "http://127.0.0.1:8080/api/users")

(http/request "POST" "http://127.0.0.1:4000/v1/chat/completions"
              :body (json/encode {:model "local" :messages [...]})
              :headers {"content-type" "application/json"
                        "authorization" "Bearer sk-xxx"})
```

`:body` 吃字串／buffer——**它不會幫你 encode**，JSON 要自己 `json/encode` 過。
header 的 key 習慣全小寫。

## ★ 三個一定要處理的地方

### ① `(res :body)` 是 **buffer**，不是字串

```janet
(def text (string (or (res :body) "")))     # ← 一定要 (string …) 包一層
(json/decode text true)
```

直接把 buffer 丟給 `json/decode` 會出事。順手用 `(or … "")` 擋掉沒有 body 的回應。

### ② `:status` 要自己判，非 2xx 不會丟例外

```janet
(def status (res :status))
(unless (and status (<= 200 status 299))
  (error (string/format "HTTP %q：%s" status (string/trim text))))
```

`http/request` 只在**連不上**時丟例外；對方回 401／500 對它來說是「成功收到回應」。

### ③ 連不上是**例外**不是 `nil`

```janet
(def [ok res] (protect (http/request "GET" url)))
(unless ok
  (error (string "連不上 " url "：" res)))
```

⚠ 連本機**一律寫 `127.0.0.1` 不要寫 `localhost`**：`localhost` 可能先解到 `::1`，
而 Janet 的 `net/connect` 只取 getaddrinfo 的第一筆，對只聽 IPv4 的後端會直接
connection refused。

## ⚠ 兩個先天限制

**沒有 TLS。** 底層是內建的 `net/connect`，`https://` 打不通。要打外網 API 的話：
走本機 proxy（`llm-http` 就是這樣解的），或用 `os/spawn` 叫 `curl`。

**做不了串流。** `http/request` 是「讀完整份 response 才回」的形狀，
SSE（`data: {...}` 逐行推）沒辦法解。要串流得另外想辦法。

## ★ HTTP 200 不代表你拿到完整答案

打 LLM 這類 API 時，**回應本文裡還有一層狀態**要看。以 OpenAI 相容格式為例：

```janet
(def d (json/decode text true))            # ⚠ 第二參 true，忘了給整條 get-in 會全 nil
(get-in d [:choices 0 :finish_reason])     # "stop"／"length"／"tool_calls"…
(get-in d [:choices 0 :message :content])  # ⚠ 可能是**空字串**，不是 nil
(get d :usage)
```

| `finish_reason` | 意思 |
|-----------------|------|
| `"stop"` | 正常講完 |
| `"length"` | **被 `max_tokens` 截斷**，答案是半截的 |
| `"tool_calls"` | 模型不作答，要你去叫工具 |
| `"content_filter"` | 被擋下來 |

**這幾種全都是 HTTP 200。** 實測（LM Studio ＋ `google/gemma-4-e4b`）：推理模型會先把
預算花在 `reasoning_tokens` 上，`max_tokens` 給小了就拿到
`finish_reason: "length"` ＋ `content: ""`——空字串是合法字串，一路過關到你手上，
看起來就像「模型沒話說」。

> 通則：**API 的回應本文自己也有錯誤語意，別只看狀態碼。**
> 細節與處理方式見 [`../FINDINGS-踩坑.md`](../FINDINGS-踩坑.md) 第十節。
