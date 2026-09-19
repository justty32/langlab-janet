# Anthropic 原生 Messages API（不經 proxy）

[← 回 llm-http README](../README.md)｜相關：[https 與 curl](https-與-curl.md)

內建 endpoint **`claude-direct`**：`:api :anthropic` ＋ `:transport :curl`，金鑰讀 `ANTHROPIC_API_KEY`，
預設 model `claude-sonnet-5`（照 claude-api skill 2026-06 的資料，現行 Sonnet 就是它）。

```janet
(def cfg (llm/endpoint "claude-direct"))
(llm/ask cfg "嗨")                                          # 一行問答
(llm/with-tools cfg msgs llm/demo-tools llm/demo-handlers)  # tool loop，一行不用改
(llm/ask-json cfg "…" nil nil :schema {…})                 # 結構化輸出 → output_config
(llm/ask-stream cfg "…")                                    # 串流也通
```

```sh
ANTHROPIC_API_KEY=sk-ant-… ./build/llm-http claude-direct "嗨"
```

⚠ **本機沒有 `ANTHROPIC_API_KEY`，真打 api.anthropic.com 那段未實測、待使用者。**
離線驗過的是：雙向轉換的純函式（`test/llm-http-anthropic.janet`）、假伺服器模擬 Anthropic
回應形狀跑完整一輪 tool loop（`test/llm-http-anthropic-loop.janet`）。

## 怎麼做到「一行不用改」

Janet 這端仍然只講 OpenAI 形狀；`:api :anthropic` 時 `dispatch.janet` 把 payload 交給
`provider-anthropic.janet`，**送之前轉過去、收回來轉回來**：

| OpenAI 形狀 | Anthropic 形狀 |
|------|------|
| `messages[role=system]` | 頂層 `system`（多則用空行接） |
| user `content` parts：`image_url` 的 data URI | `{type image, source {type base64, media_type, data}}`；http URL → `source {type url}` |
| assistant `tool_calls[{id function{name arguments}}]` | `content [{type tool_use, id, name, input}]`（`arguments` 是 JSON 字串，要 decode） |
| `role: "tool"`（`tool_call_id`） | `user` ＋ `[{type tool_result, tool_use_id, content}]`；**連續的 tool 訊息合成同一則 user** |
| `tools[{function{name description parameters}}]` | `[{name description input_schema}]` |
| `tool_choice` `"auto"`／`"none"`／`"required"`／`{function}` | `{type auto}`／`{type none}`／`{type any}`／`{type tool, name}` |
| `max_tokens` | **必填**，沒給補 4096 |
| `stop` | `stop_sequences` |
| `response_format` `json_schema` | `output_config.format`；`json_object` 沒有對應，改塞一句 system 提示 |
| 回應 `content[text]`／`[tool_use]` | `choices[0].message.content`／`tool_calls`（`arguments` encode 回字串） |
| `stop_reason` `end_turn`／`max_tokens`／`tool_use`／`refusal` | `finish_reason` `stop`／`length`／`tool_calls`／`content_filter` |
| `usage{input_tokens output_tokens}` | `usage{prompt_tokens completion_tokens total_tokens}` |

實測（`examples/llm-http/10-anthropic-direct.janet`，不打網路的那兩段）：

```
── ② to-anthropic：OpenAI payload 轉出去長怎樣 ──
  system 抽到頂層：只用繁體中文
  max_tokens：300（Anthropic 必填，沒給會補 4096）
  tools[0] 的欄位：@[:description :input_schema :name]
  messages 剩 1 則（system 拿掉了）

── ③ from-anthropic：Anthropic 回應轉回來長怎樣 ──
  reply-text          = 我查一下。
  reply-finish-reason = "tool_calls"（tool_use → tool_calls）
  tool_calls[0].function.arguments = "{\"city\":\"\\u53F0\\u5317\"}"（回到 JSON 字串）
  reply-usage         = @{:completion_tokens 12 :prompt_tokens 30 :total_tokens 42}
```

## ⚠ 要知道的幾件事

- **header 不一樣**：`x-api-key` 不是 `Authorization: Bearer`，另外要 `anthropic-version: 2023-06-01`
  （endpoint 的 `:anthropic-version` 可覆寫；`anthropic-beta` 之類放 `:headers`）。
  金鑰沒設時 resolve 會填預設的 `"dummy"`，這條線會**當場**丟「這條 Anthropic 線沒有金鑰」，不會等 401。
- **不認得的 OpenAI 欄位會被丟掉**（`seed`／`frequency_penalty`／`stream_options`…）：Anthropic 對未知
  頂層欄位回 400。Anthropic 自己的欄位（`thinking`／`output_config`／`metadata`／`top_k`／`stop_sequences`）
  從 `chat` 的 `:extra` 放進來會原樣透傳，例如 `:extra {:thinking {:type "adaptive"}}`。
- **轉回來的 message 多帶 `:anthropic_content`**（原始 content 陣列）。`with-tools` 把整則 message
  接回歷史再送時，會**原樣**送回這份而不重組——thinking block 與 signature 都在裡面，多輪 tool loop
  才不會被 400 擋下。把這份歷史轉送到 OpenAI 相容端點前請把這個 key 拿掉（嚴格的伺服器會拒收）。
- **`temperature` 與 `top_p` 在 4.6 之後的模型不能同時給**（會 400）；本模組不幫你擋，二選一。
- 走 `:transport :http`（例如打假伺服器）也行，但真的 api.anthropic.com 是 https，只有 curl 打得通。

`lite.yaml` 的 `claude` endpoint（經 proxy）仍在；兩條的差別只在「誰做轉換」——proxy 或本機。
