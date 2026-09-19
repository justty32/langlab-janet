# https 與 curl（含 `:retry`、`ask-json`、`list-models`）

[← 回 llm-http README](../README.md)｜相關：[Anthropic 原生](anthropic-原生.md)、[串流](streaming.md)

spork/http 底層是 `net/connect`，**沒有 TLS**。以前 `:url` 寫 `https://` 一定打不通，
只能讓 litellm proxy 代打；現在 `transport.janet` 會**自動選路**：

| 條件 | 傳輸 |
|------|------|
| `:url` 以 `https://` 開頭，**或** endpoint 給 `:transport :curl` | `transport-curl.janet`：`os/spawn` 呼叫系統的 `curl` |
| 其餘（`http://`） | 照舊 spork/http |

```janet
(def ds (llm/endpoint {:model "deepseek-v4-flash"
                       :url "https://api.deepseek.com/v1/chat/completions"
                       :api-key-env "DEEPSEEK_API_KEY"}))
(llm/ask ds "嗨")                     # https → 自動走 curl，不用寫 :transport
(llm/list-models ds)                  # GET https://api.deepseek.com/v1/models
```

- `(llm/curl-available?)` 探一次 PATH 上有沒有 curl（環境變數 `LLM_HTTP_CURL` 可指到別的路徑）。
- 沒 curl 的機器：`https://` 仍然打不通，錯誤是「叫不動 curl（不在 PATH 上？）」；要打外部服務就回頭架 proxy。
- `:timeout` 秒數對應 `--max-time`；超時的錯誤是「連不上 …：逾時（curl --max-time）」。

## ⚠ 金鑰不上命令列

`ps` 看得到每個行程的整條 argv，所以 `-H "Authorization: Bearer sk-…"` 這種寫法會把金鑰洩給同機器的所有人。
實測後的做法：**header 全部寫進一個 0600 的暫存檔**，命令列只有 `-H @那個檔`；body 從 stdin 餵（`--data-binary @-`）。
暫存檔用 `(os/umask 8r077)` 包住 `spit` 建立（建檔當下就是 0600，沒有「先建再 chmod」的空窗），
curl 結束後 `defer` 刪掉。

拿一支假 curl（把 argv 與 header 檔內容記到檔案）實測，命令列長這樣：

```
argv: -sS -X POST -H @/tmp/llm-http-2a431d517d18de9f.hdr -w
%{http_code} --data-binary @- https://example.invalid/v1/chat/completions
header 檔內容：
   content-type: application/json
   authorization: Bearer sk-VERY-SECRET   權限 -rw-------
```

（`-w` 的參數含換行，所以印成兩行。）`test/llm-http-curl.janet` 另外驗「用完暫存檔有刪」。

其他實測踩到的：不用 `--fail`（它會把非 2xx 的 body 吞掉，你就看不到伺服器說「model 不存在」還是「金鑰錯」），
改用 `-w '\n%{http_code}'` 把狀態碼接在 body 最後一行自己切；curl 自己的錯誤（exit 6／7／28／35／60）
翻成中文，例如 `連不上 http://127.0.0.1:45799/x：連不上（curl exit 7）：curl: (7) Failed to connect …`。

## `:retry`：只對值得重試的錯誤重試

```janet
(llm/ask cfg "嗨" nil nil :retry 3)                                  # 最多多試 3 次
(llm/chat cfg msgs :retry {:times 3 :base 0.5 :cap 8
                           :on-retry (fn [n err wait] (eprintf "第 %d 次重試，等 %.1f 秒：%s" n wait err))})
```

```sh
./build/llm-http --retry 3 deepseek "嗨"
```

只有三種錯誤會重試：**連不上**、**HTTP 5xx**、**HTTP 429**；400／401／404 重試一百次還是一樣，直接丟出去。
退避是 `base × 2ⁿ`（上限 `cap`）再乘 0.5～1.0 的抖動，抖動用自己的 rng（裸的 `math/random` 每次跑都同一串，
見 `snippets/retry-timeout.janet`）。錯誤是靠**訊息文字**分類的（`retryable?`／`error-status`），
`test/llm-http-extras.janet` 用假伺服器「503 兩次再 200」驗過，也驗過 400 只打一次。

## 結構化輸出：`ask-json`

```janet
(llm/ask-json cfg "台北在哪個國家？回 JSON，key 用 city／country" "只回 JSON 物件")
# → @{:city "台北" :country "台灣"}          （沒給 :schema → response_format {:type "json_object"}）
(llm/ask-json cfg "東京的資料" nil nil :schema {:type "object" :properties {…} :required […]})
#                                              （給了 :schema → json_schema，name 預設 "reply"，strict true）
```

兩層保險：送 `response_format`（認得的伺服器會強制合法 JSON），回來的字串**再自己解**——
OpenRouter 有些模型會靜靜無視 `response_format`，這一層才是真的保證。會先剝掉 ```` ```json ```` 圍欄
（小模型很愛包）；解不出來丟中文錯誤並附上原文：

```
模型回的不是合法 JSON：decode error at position 0: unexpected character
原文：我不想回 JSON
```

`:api :anthropic` 那條由轉換層改成 `output_config.format`（`json_object` 沒有對應，改塞一句 system 提示）。
`chat`／`ask` 也直接吃 `:response-format`，`reply-usage` 拿 token 用量。
能跑的示範 → [`../../examples/llm-http/11-json-output.janet`](../../../examples/llm-http/11-json-output.janet)。
