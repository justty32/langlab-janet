# Anthropic 串流事件的合併 —— 把 message_start／content_block_*／message_delta 組回一則完整回應。
#
# Anthropic 的 SSE 不是「一塊塊的 message」而是**事件**（data 裡的 type 欄位）：
#   message_start        {message {id model usage{input_tokens}}}
#   content_block_start  {index content_block {type text|tool_use|thinking, id, name…}}
#   content_block_delta  {index delta {type text_delta text | input_json_delta partial_json | thinking_delta …}}
#   content_block_stop   {index}
#   message_delta        {delta {stop_reason} usage {output_tokens}}
#   message_stop
#   ping／error
# 合併方式：依 index 把 block 收齊（text 接起來、tool_use 的 partial_json 接起來再 decode），
# 最後組成一份 Anthropic 回應交給 anthropic-res/from-anthropic，就跟非串流一模一樣。
#
# ⚠ 收到 type=error 的事件（例如 overloaded）要直接丟錯，不然合出來是一份空回應。

(import spork/json)
(import ./anthropic-res :as ares)

(defn make-anthropic-merger
  ``回 @{:feed (fn [event]) :finish (fn [])}，介面跟 sse/make-openai-merger 一樣。
  on-delta（可省略）每收到一段 text_delta 就叫一次。``
  [&opt on-delta]
  (def st @{:message @{} :blocks @{} :stop nil :out-tokens nil :n 0})
  (defn feed [ev]
    (++ (st :n))
    (case (get ev :type)
      "message_start"
      (put st :message (or (get ev :message) @{}))

      "content_block_start"
      (let [b (get ev :content_block)
            slot @{:type (get b :type) :text @"" :json @""}]
        (when-let [id (get b :id)] (put slot :id id))
        (when-let [nm (get b :name)] (put slot :name nm))
        (when-let [t (get b :text)] (buffer/push (slot :text) t))
        (put (st :blocks) (get ev :index) slot))

      "content_block_delta"
      (let [slot (get (st :blocks) (get ev :index))
            d (get ev :delta)]
        (when slot
          (case (get d :type)
            "text_delta" (let [t (get d :text)]
                           (buffer/push (slot :text) t)
                           (when on-delta (on-delta t)))
            "input_json_delta" (buffer/push (slot :json) (get d :partial_json))
            nil)))

      "message_delta"
      (do (when-let [sr (get-in ev [:delta :stop_reason])] (put st :stop sr))
          (when-let [u (get ev :usage)] (put st :usage u)))

      "error"
      (error (string "Anthropic 串流回了錯誤：" (string/format "%q" (get ev :error))))

      nil))
  (defn finish []
    (def content
      (seq [i :in (sorted (keys (st :blocks)))]
        (def b (get (st :blocks) i))
        (case (b :type)
          "text" {:type "text" :text (string (b :text))}
          "tool_use" {:type "tool_use" :id (b :id) :name (b :name)
                      :input (let [[ok v] (protect (json/decode (string (b :json)) true))]
                               (if (and ok (dictionary? v)) v {}))}
          {:type (b :type)})))
    (def m (st :message))
    (def usage @{:input_tokens (get-in m [:usage :input_tokens] 0)
                 :output_tokens (get-in st [:usage :output_tokens] 0)})
    (def res (ares/from-anthropic {:id (get m :id) :model (get m :model)
                                   :stop_reason (st :stop) :content content :usage usage}))
    (put res :chunks (st :n))
    res)
  @{:feed feed :finish finish})
