# Anthropic Messages API 的回應 → OpenAI chat completion 形狀（純函式，不打網路）。
#
# 目的：轉回來之後 reply-text／reply-message／reply-finish-reason／with-tools 一行都不用改。
#
#   content[text]                  → choices[0].message.content（多段 text 用空字串接起來）
#   content[tool_use{id name input}] → message.tool_calls[{id type:"function" function{name arguments}}]
#                                    （arguments 要 json/encode 回**字串**，跟 OpenAI 一樣）
#   stop_reason                    → finish_reason：end_turn/stop_sequence→stop、max_tokens→length、
#                                    tool_use→tool_calls、refusal→content_filter
#   usage{input_tokens output_tokens} → usage{prompt_tokens completion_tokens total_tokens}
#
# ⚠ 只回 tool_use 沒有 text 時 content 是 **nil**（OpenAI 也是 null），ask 會因此丟例外——
#   那是對的，該走 with-tools。
# ★ 轉出來的 message 多帶一個 :anthropic_content（原始 content 陣列）：with-tools 把整則
#   message 接回歷史再送回 Anthropic 時，anthropic-req 會用它原樣回傳（含 thinking block），
#   多輪 tool loop 才不會被「thinking block 缺了」的 400 擋下。送到 OpenAI 相容端點時不會帶它。

(import spork/json)

(def finish-reasons
  "stop_reason → finish_reason。"
  {"end_turn"      "stop"
   "stop_sequence" "stop"
   "max_tokens"    "length"
   "tool_use"      "tool_calls"
   "refusal"       "content_filter"
   "pause_turn"    "stop"})

(defn finish-reason
  [stop-reason]
  (if (nil? stop-reason) nil (get finish-reasons stop-reason stop-reason)))

(defn tool-call
  "一個 tool_use block → 一個 OpenAI tool_call。"
  [block]
  @{:id   (get block :id)
    :type "function"
    :function @{:name      (get block :name)
                :arguments (string (json/encode (or (get block :input) {})))}})

(defn message-of
  "content block 陣列 → OpenAI 的 assistant message。"
  [content]
  (def texts @[])
  (def calls @[])
  (each b (or content [])
    (case (get b :type)
      "text"     (array/push texts (get b :text))
      "tool_use" (array/push calls (tool-call b))
      nil))
  (def m @{:role "assistant"
           :content (if (empty? texts) nil (string/join texts ""))
           :anthropic_content content})
  (unless (empty? calls) (put m :tool_calls calls))
  m)

(defn usage-of
  [u]
  (when u
    (def in  (or (get u :input_tokens) 0))
    (def out (or (get u :output_tokens) 0))
    (def usage @{:prompt_tokens in :completion_tokens out :total_tokens (+ in out)})
    (when-let [c (get u :cache_read_input_tokens)]
      (put usage :prompt_tokens_details @{:cached_tokens c}))
    usage))

(defn from-anthropic
  ``整份 Anthropic 回應 → OpenAI chat completion 形狀（新的 table）。``
  [res]
  (def out @{:id     (get res :id)
             :object "chat.completion"
             :model  (get res :model)
             :choices @[@{:index 0
                          :message (message-of (get res :content))
                          :finish_reason (finish-reason (get res :stop_reason))}]})
  (when-let [u (usage-of (get res :usage))] (put out :usage u))
  (when-let [sd (get res :stop_details)] (put out :stop_details sd))
  out)
