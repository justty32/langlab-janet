# 47 系列教學共用的**假 OpenAI 相容後端**——不用金鑰、不打外網。
#
# ⚠ 這支檔案**沒有頂層副作用**：import 它不會開 port，要自己呼叫 start。
#
# 它只做一件事：在同一個行程裡聽一個 127.0.0.1 的 port，收 /v1/chat/completions
# 的 POST，回一份預先寫好的 JSON。所以每支範例都能離線跑完整條路徑：
# 組 payload → HTTP POST → 解回應 → 挖答案。
#
# 換成真模型只要改一行：把 (fs :url) 換成真的位址、:api-key 換成真金鑰，
# 例如 "http://127.0.0.1:4000/v1/chat/completions"（litellm proxy）。

(import spork/http)
(import spork/json)

(defn text-reply
  "組一份「模型講了一句話」的回應。usage 是假的但固定，方便累計示範。"
  [content &named finish prompt-tokens completion-tokens]
  {:id "chatcmpl-fake"
   :object "chat.completion"
   :model "fake-model"
   :choices [{:index 0
              :finish_reason (or finish "stop")
              :message {:role "assistant" :content content}}]
   :usage {:prompt_tokens (or prompt-tokens 26)
           :completion_tokens (or completion-tokens 9)
           :total_tokens (+ (or prompt-tokens 26) (or completion-tokens 9))}})

(defn tool-call-reply
  ``組一份「模型要你叫工具」的回應。arguments 照 OpenAI 的規矩是**一段 JSON 字串**，
  不是巢狀物件——這是新手最常看走眼的地方。``
  [name args &opt id]
  {:id "chatcmpl-fake"
   :object "chat.completion"
   :model "fake-model"
   :choices [{:index 0
              :finish_reason "tool_calls"
              :message {:role "assistant"
                        :content nil
                        :tool_calls [{:id (or id "call_1")
                                      :type "function"
                                      :function {:name name
                                                 :arguments (json/encode args)}}]}}]
   :usage {:prompt_tokens 48 :completion_tokens 17 :total_tokens 65}})

(defn last-user-text
  "取最後一則 user 訊息的文字；content 是 parts 陣列時把 :text 那幾段接起來。"
  [payload]
  (def m (last (filter |(= "user" (get $ :role)) (get payload :messages []))))
  (def c (and m (get m :content)))
  (cond
    (string? c) c
    (indexed? c) (string/join (map |(get $ :text "") (filter |(= "text" (get $ :type)) c)) " ")
    ""))

(defn default-reply
  ``預設規則（跟 test/llm-http-server.janet 同一套，多加了截斷那條）：
    ① max_tokens 小到不合理 → finish_reason="length"、content 是空字串
    ② 歷史裡有 role="tool"   → 拿工具結果作答
    ③ 這次帶了 :tools        → 回一則 tool_calls
    ④ 其餘                   → 直接回一句話``
  [payload _n]
  (def tool-msg (find |(= "tool" (get $ :role)) (get payload :messages [])))
  (cond
    (and (payload :max_tokens) (<= (payload :max_tokens) 8))
    [200 {:choices [{:finish_reason "length"
                     :message {:role "assistant" :content ""}}]
          :usage {:completion_tokens 8
                  :completion_tokens_details {:reasoning_tokens 5}}}]

    tool-msg
    [200 (text-reply (string "查到了：" (get tool-msg :content)))]

    (payload :tools)
    [200 (tool-call-reply "get_weather" {:city "Taipei"})]

    [200 (text-reply (string "（假後端）你剛剛說：" (last-user-text payload)))]))

(defn start
  ``起一台假後端，回 @{:server :port :url :log}。

  :port   聽哪個 port（各範例用不同的，免得同時跑撞在一起）
  :reply  (fn [payload 第幾次呼叫] -> [HTTP狀態碼 回應表])，預設 default-reply

  :log 是一個 array，每收到一次請求就把解好的 payload push 進去——
  範例靠它印出「我到底送了什麼上去」。``
  [&named port reply]
  (default port 45820)
  (default reply default-reply)
  (def log @[])
  (defn handler [req]
    (http/read-body req)
    (def payload (json/decode (string (or (req :body) "{}")) true))
    (array/push log payload)
    (def [status body] (reply payload (length log)))
    {:status status
     :headers {"content-type" "application/json"}
     :body (json/encode body)})
  (def server (http/server (http/router {"/v1/chat/completions" handler})
                           "127.0.0.1" port))
  @{:server server
    :port port
    :log log
    :url (string "http://127.0.0.1:" port "/v1/chat/completions")})

(defn stop
  "關掉假後端。⚠ 一定要關，不然行程結束不了（ev loop 還在等它）。"
  [fs]
  (:close (fs :server)))
