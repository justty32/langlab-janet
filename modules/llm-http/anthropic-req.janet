# OpenAI 形狀的 payload → Anthropic Messages API 的 request（純函式，不打網路）。
#
# 對照表（OpenAI → Anthropic）：
#   messages[role=system]           → 頂層 system（多則就用空行接起來）
#   user content 字串               → 原樣
#   user content parts              → text／image block；data URI 拆成 base64 source，http URL 用 url source
#   assistant + tool_calls          → content [text?, tool_use{id name input}]（arguments 是 JSON 字串，要 decode）
#   role=tool（tool_call_id）        → user + [tool_result{tool_use_id content}]；**連續的 tool 訊息合成同一則 user**
#   tools[{function{name description parameters}}] → [{name description input_schema}]
#   tool_choice "auto"/"none"/"required"/{function} → {type auto/none/any/tool}
#   max_tokens                      → 必填，沒給就補 default-max-tokens
#   stop                            → stop_sequences
#   response_format json_schema     → output_config.format（json_object 沒有對應，改塞一句 system 提示）
#
# ⚠ 不認得的 OpenAI 欄位（seed／frequency_penalty／stream_options…）會被**丟掉**：
#   Anthropic 對未知的頂層欄位回 400，與其整個請求炸掉不如靜靜略過。
#   Anthropic 自己的欄位（thinking／output_config／metadata／top_k／stop_sequences／system）
#   可以從 chat 的 :extra 放進來，會原樣透傳。
# ⚠ assistant 訊息若帶 :anthropic_content（provider-anthropic 轉回來時留的原始 content），
#   會**原樣**送回去而不重組——thinking block 與 signature 都在裡面，tool loop 多輪才不會被 400。

(import spork/json)

(def default-max-tokens
  "Anthropic 的 max_tokens 是必填；呼叫端沒給就用這個。"
  4096)

(def passthrough-keys
  "從 OpenAI payload 原樣透傳到 Anthropic request 的欄位（Anthropic 自己也認得的）。"
  [:model :max_tokens :temperature :top_p :top_k :stream :metadata :stop_sequences
   :thinking :output_config :system :service_tier])

(defn- parse-data-uri
  "data:<mime>;base64,<data> → [mime data]；不是 data URI 回 nil。"
  [s]
  (when (string/has-prefix? "data:" s)
    (when-let [comma (string/find "," s)]
      (def head (string/slice s 5 comma))
      (def semi (string/find ";" head))
      [(if semi (string/slice head 0 semi) head) (string/slice s (inc comma))])))

(defn image-block
  "OpenAI 的 image_url part → Anthropic 的 image block。"
  [url]
  (if-let [[mime data] (parse-data-uri url)]
    {:type "image" :source {:type "base64" :media_type mime :data data}}
    {:type "image" :source {:type "url" :url url}}))

(defn- convert-part
  [p]
  (case (get p :type)
    "text"      {:type "text" :text (get p :text)}
    "image_url" (image-block (get-in p [:image_url :url]))
    p))

(defn- convert-content
  "字串原樣；parts 陣列逐個轉。"
  [c]
  (if (indexed? c) (map convert-part c) c))

(defn- decode-args
  [raw]
  (cond
    (dictionary? raw) raw
    (or (nil? raw) (empty? raw)) {}
    (let [[ok v] (protect (json/decode raw true))] (if (and ok (dictionary? v)) v {}))))

(defn- assistant-blocks
  "assistant 訊息 → content block 陣列（有 :anthropic_content 就直接用那份）。"
  [m]
  (if-let [raw (get m :anthropic_content)]
    raw
    (do
      (def blocks @[])
      (def text (get m :content))
      (when (and (string? text) (not (empty? text)))
        (array/push blocks {:type "text" :text text}))
      (when (indexed? text) (array/concat blocks (map convert-part text)))
      (each c (or (get m :tool_calls) [])
        (array/push blocks {:type  "tool_use"
                            :id    (get c :id)
                            :name  (get-in c [:function :name])
                            :input (decode-args (get-in c [:function :arguments]))}))
      blocks)))

(defn convert-messages
  "回 [system-string-or-nil messages-array]。"
  [messages]
  (def systems @[])
  (def out @[])
  (each m messages
    (case (get m :role)
      "system" (array/push systems (string (get m :content)))
      "user"   (array/push out @{:role "user" :content (convert-content (get m :content))})
      "assistant" (array/push out @{:role "assistant" :content (assistant-blocks m)})
      "tool"
      (let [block {:type "tool_result" :tool_use_id (get m :tool_call_id)
                   :content (string (get m :content))}
            prev (last out)]
        # ★ 連續的 tool 結果要塞進**同一則** user 訊息，Anthropic 才收
        (if (and prev (= "user" (prev :role)) (indexed? (prev :content))
                 (= "tool_result" (get-in prev [:content 0 :type])))
          (array/push (prev :content) block)
          (array/push out @{:role "user" :content @[block]})))
      (error (string "不認得的 role：" (get m :role)))))
  [(if (empty? systems) nil (string/join systems "\n\n")) out])

(defn convert-tools
  [tools]
  (map (fn [t] {:name (get-in t [:function :name])
                :description (get-in t [:function :description])
                :input_schema (get-in t [:function :parameters])})
       tools))

(defn convert-tool-choice
  [tc]
  (cond
    (= tc "auto") {:type "auto"}
    (= tc "none") {:type "none"}
    (= tc "required") {:type "any"}
    (dictionary? tc) {:type "tool" :name (get-in tc [:function :name])}
    nil))

(defn to-anthropic
  ``整份 OpenAI 形狀的 payload → Anthropic Messages request（新的 table）。``
  [payload]
  (def out @{})
  (each k passthrough-keys
    (when-let [v (get payload k)] (put out k v)))
  (unless (out :max_tokens) (put out :max_tokens default-max-tokens))
  (def [sys msgs] (convert-messages (get payload :messages)))
  (put out :messages msgs)
  (def sys-parts @[])
  (when (out :system) (array/push sys-parts (out :system)))
  (when sys (array/push sys-parts sys))
  (when-let [tools (get payload :tools)] (put out :tools (convert-tools tools)))
  (when-let [tc (convert-tool-choice (get payload :tool_choice))] (put out :tool_choice tc))
  (when-let [stop (get payload :stop)]
    (put out :stop_sequences (if (indexed? stop) stop [stop])))
  (when-let [rf (get payload :response_format)]
    (case (get rf :type)
      "json_schema" (put out :output_config
                         {:format {:type "json_schema" :schema (get-in rf [:json_schema :schema])}})
      "json_object" (array/push sys-parts "只回傳一個合法的 JSON 物件，不要有任何其他文字或 markdown 圍欄。")))
  (unless (empty? sys-parts) (put out :system (string/join sys-parts "\n\n")))
  out)
