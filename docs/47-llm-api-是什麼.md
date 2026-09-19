# 47 · LLM API 到底是什麼

**它就是一個 HTTP POST。** 你把一份 JSON 送到某個網址，對方回一份 JSON，裡面有一句話。
沒有連線、沒有 session、沒有狀態——這一點決定了後面所有事情。

這是「從零寫一個 AI agent」系列的第一篇。假設你會寫程式但沒碰過 LLM API。
HTTP 那一層的基本功在 [17 用 spork/http 打 api](17-用-spork-http-打-api.md)，這裡只講 LLM 這一層。

可跑範例：[`../examples/agent-tutorial/47-api.janet`](../examples/agent-tutorial/47-api.janet)
——**不用金鑰、不用網路**，它自己在同一個行程裡起一台假伺服器。

```sh
janet examples/agent-tutorial/47-api.janet
```

## 一次呼叫的四個東西

| 你要給 | 是什麼 |
|--------|--------|
| 網址 | `POST http://…/v1/chat/completions`，OpenAI 相容伺服器都是這條路徑 |
| 金鑰 | `Authorization: Bearer sk-…` |
| `model` | 要跟哪個模型講話 |
| `messages` | **整個對話**，一個陣列 |

`messages` 裡每則有 `role` 與 `content`，role 只有三種：

- `system`——你給模型的行為設定（語氣、格式、它是誰）。放最前面。
- `user`——人講的話。
- `assistant`——模型講過的話。多輪對話時你要把它的舊回答也放回去（見 [47b](47b-多輪對話.md)）。

## 送出去的東西長這樣

`build-payload` 是純函式，不連線也印得出來：

```janet
(import ../modules/llm-http/init :as llm)
(def cfg (llm/endpoint {:model "fake-model" :url "http://127.0.0.1:45821/v1/chat/completions"}))
(llm/build-payload cfg
                   @[@{:role "system" :content "You are a terse assistant."}
                     @{:role "user"   :content "What is the weather in Taipei?"}]
                   :temperature 0.5 :max-tokens 128)
```

實際跑出來像這樣（範例第 ① 段）：

```json
{
  "max_tokens": 128,
  "model": "fake-model",
  "messages": [
    {"role": "system", "content": "You are a terse assistant."},
    {"role": "user",   "content": "What is the weather in Taipei?"}
  ],
  "temperature": 0.5
}
```

⚠ **`spork/json` 會把非 ASCII 逃逸成 `\uXXXX`**。中文的 content 印出來滿滿的 `你`，
看起來很像壞了——它是合法 JSON，對端解得開。範例裡刻意用英文，就是為了印出來讀得下去。

## 回來的東西長這樣

```json
{
  "id": "chatcmpl-fake",
  "object": "chat.completion",
  "model": "fake-model",
  "choices": [
    {"index": 0,
     "finish_reason": "stop",
     "message": {"role": "assistant", "content": "…答案在這裡…"}}
  ],
  "usage": {"prompt_tokens": 26, "completion_tokens": 9, "total_tokens": 35}
}
```

三個要看的欄位，一個都別漏：

```janet
(get-in {:choices [{:message {:content "sunny"}}]} [:choices 0 :message :content])  # => "sunny"
(get-in {:choices [{:finish_reason "stop"}]} [:choices 0 :finish_reason])           # => "stop"
(get-in {:usage {:prompt_tokens 26}} [:usage :prompt_tokens])                       # => 26
```

模組把這三個包成 `reply-text`、`reply-finish-reason`、`truncated?`。
只要一句答案的話 `ask` 一行解決：

```janet
(llm/ask cfg "Say it again." "You are a terse assistant.")
```

## token 是什麼

模型看不到字元，它看到的是 **token**：一段常見字串被切成一個單位。
英文大約 4 個字元一個 token，中文大約一個字一個 token（各家切法不同，只能當估計）。

`usage` 三個數字：`prompt_tokens`（你送上去的）、`completion_tokens`（它回的）、`total_tokens`。
**計價與長度上限都是以 token 算的**，所以這是你唯一的儀表板。

⚠ `prompt_tokens` 是**每次都重算**的：多輪對話第五輪會把前四輪整份重送一次。
成本怎麼估、為什麼 tool loop 特別貴 → [47f](47f-錯誤與成本.md)。

## ★ HTTP 200 不代表你拿到完整答案

`finish_reason` 是**回應本文裡的第二層狀態**：

| 值 | 意思 |
|----|------|
| `"stop"` | 正常講完 |
| `"length"` | 撞到 `max_tokens`，答案是半截的 |
| `"tool_calls"` | 它不作答，要你去叫工具（[47c](47c-tool-calling.md)） |
| `"content_filter"` | 被擋下來 |

**這幾種全都是 HTTP 200。** 實測過最難查的一種：推理模型把預算花光時，
`content` 回一個**空字串**、`finish_reason` 是 `"length"`、HTTP 仍然 200
（見 [`../FINDINGS-踩坑.md`](../FINDINGS-踩坑.md) 第十節）。空字串是合法字串，
一路過關到你手上，看起來就像「模型沒話說」。

```janet
(get-in {:choices [{:finish_reason "length"}]} [:choices 0 :finish_reason])  # => "length"
(get-in {:choices [{:message {:content ""}}]} [:choices 0 :message :content])  # => ""
```

養成習慣：**每次都看 `finish_reason`**，不要只看有沒有丟例外。

下一步：[47b 多輪對話](47b-多輪對話.md)——模型「記得」你說過什麼，其實是你每次都重送。
