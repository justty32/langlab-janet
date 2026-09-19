# 47c · tool calling 白話

**模型不會執行任何東西。** 它只會回一段 JSON 說「請幫我叫 `get_weather`，參數是 `{"city":"Taipei"}`」。
真正去查天氣的是你的程式；查完你再用一則 `role:"tool"` 的訊息把結果送回去，它才作答。

想通這件事，agent 就沒有神祕感了：**它是一個會提出請求的文字產生器，權限全在你手上。**

前一篇：[47b 多輪對話](47b-多輪對話.md)。
可跑範例（離線）：[`../examples/agent-tutorial/47c-tools.janet`](../examples/agent-tutorial/47c-tools.janet)。

## 四步

1. 送 `messages` ＋ `tools`（工具清單）。
2. 模型回一則 `assistant` 訊息，裡面有 `tool_calls`、`content` 是 `null`。
3. 你解出參數、**在本地執行**、把結果包成 `role:"tool"` 的訊息。
4. 再送一次（整份歷史），模型拿著結果作答。

## ① 宣告工具：一份 JSON schema

```janet
(llm/tool-spec "get_weather" "Current weather of a city"
               {:type "object"
                :properties {:city {:type "string" :description "city name"}}
                :required ["city"]})
```

`parameters` 就是一份 [JSON schema](https://json-schema.org/)，用 Janet 的 struct 直接寫。
組出來的形狀（範例第 ① 段實測）：

```json
[{"type": "function",
  "function": {"name": "get_weather",
               "description": "Current weather of a city",
               "parameters": {"type": "object",
                              "properties": {"city": {"type": "string",
                                                      "description": "city name"}},
                              "required": ["city"]}}}]
```

**`description` 是給模型讀的**，不是給人讀的註解。寫得含糊，模型就叫錯工具或傳錯參數。
每個欄位都寫一句話，值域固定的用 `"enum"` 列出來。

## ② 模型回什麼

```
finish_reason = tool_calls
content       = nil   ← 沒有答案，它在等工具結果
tool_calls    =
[{"id": "call_1",
  "type": "function",
  "function": {"name": "get_weather", "arguments": "{\"city\":\"Taipei\"}"}}]
```

⚠ **`arguments` 是一段 JSON 字串，不是巢狀物件**。要再 `json/decode` 一次：

```janet
(import spork/json)
(json/decode "{\"city\":\"Taipei\"}" true)   # => @{:city "Taipei"}
```

第二個參數給 `true`，key 才會是 keyword；忘了給的話 `(get args :city)` 一路回 `nil`。

⚠ 模型**可能一次要求好幾個工具**（`tool_calls` 是陣列），也可能傳你沒宣告的參數、
或漏掉 `required` 的欄位。它產生的是文字，不是通過型別檢查的呼叫。

## ③ 執行，然後把結果送回去

```janet
(array/push 歷史 msg)                       # ★ 整則 assistant 訊息原樣接回去
(array/push 歷史 @{:role "tool"
                   :tool_call_id (get c :id)
                   :content 結果字串})
```

⚠ **assistant 那則不能只留 `content`**。`tool_calls` 那段是後面 `role:"tool"` 訊息的錨點，
拿掉就對不起來，後端會回 400 或模型整個答非所問。

⚠ `tool_call_id` 要跟 `tool_calls[i].id` 一字不差。多個工具就多則 `role:"tool"`，各自對各自的 id。

⚠ `content` 必須是**字串**。回傳 table 的話自己 `json/encode` 一次再送。

## ④ 再送一次

實測（範例第 ③④ 段）：

```
arguments 原文 = "{\"city\":\"Taipei\"}"  （字串！）
decode 之後    = @{:city "Taipei"}
本地執行結果   = {"city":"Taipei","temp_c":31,"cond":"sunny"}
答案 = 查到了：{"city":"Taipei","temp_c":31,"cond":"sunny"}
歷史四則：user → assistant → tool → assistant
```

## handler 丟例外怎麼辦

**接住它，把錯誤訊息當成工具結果送回去。** 不要讓整條 loop 掛掉——
模型看得懂錯誤訊息，通常會換參數重試或改口說「查不到」。

```janet
(defn 執行工具 [name args]
  (def [ok v] (protect (case name
                         "get_weather" (查天氣 args)
                         (error (string "沒有名為 " name " 的工具")))))
  (if ok (if (string? v) v (string (json/encode v)))
    (string "工具執行失敗：" v)))
```

```
工具執行失敗：沒有火星的觀測站
工具執行失敗：沒有名為 launch_missile 的工具
```

⚠ **工具名沒宣告過也要走同一條路**。模型偶爾會憑空捏一個工具名出來，
那時丟例外等於讓使用者的程式為模型的幻覺陪葬。

## 權限這件事現在就要想

工具是你寫的，所以「模型能做什麼」完全由你決定。
`get_weather` 很安全；`run_shell` 就等於把 shell 交給一個會猜的東西。
**危險的工具要嘛不給，要嘛執行前先問人。**

下一步：[47d 自己寫一個 agent loop](47d-自己寫-agent-loop.md)——把這四步包成一個 while。
