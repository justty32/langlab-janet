# llm-http：拿一台**假的 OpenAI 相容後端**把整條 HTTP 路徑走一遍。
#
# 不碰真的 LLM、不打外網：spork/http 的 server 就跑在同一個行程裡，靠 ev loop
# 跟 client 併行。驗的是「參數真的送到 wire 上」與「多輪 tool loop 真的轉得起來」。
#
# 假後端的規則：
#   ① 歷史裡有 role="tool" → 拿它的內容作答
#   ② 沒有但這次帶了 :tools → 回一則 tool_calls
#   ③ 兩者皆非（單純問答）→ 直接回一句話

(import spork/http)
(import spork/json)
(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

(def port 45711)
(var seen-tool-result nil)
(var seen-payload nil)
(var seen-headers nil)

(defn- fake-backend [req]
  (http/read-body req)
  (def body (json/decode (string (or (req :body) "{}")) true))
  (set seen-payload body)
  (set seen-headers (req :headers))
  (def tool-msg (find |(= "tool" (get $ :role)) (body :messages)))
  (when tool-msg (set seen-tool-result (get tool-msg :content)))
  {:status 200
   :headers {"content-type" "application/json"}
   :body (json/encode
           (cond
             # max_tokens 小到不合理 → 模擬「推理模型把預算花光」：HTTP 200、
             # finish_reason=length、content 是空字串（真的在 LM Studio 上遇過）
             (and (body :max_tokens) (<= (body :max_tokens) 8))
             {:choices [{:finish_reason "length"
                         :message {:role "assistant" :content ""}}]
              :usage {:completion_tokens 8
                      :completion_tokens_details {:reasoning_tokens 5}}}

             tool-msg
             {:choices [{:message {:role "assistant"
                                   :content (string "台北 " (get tool-msg :content))}}]}
             (body :tools)
             {:choices [{:message {:role "assistant"
                                   :tool_calls [{:id "call_1"
                                                 :type "function"
                                                 :function {:name "get_weather"
                                                            :arguments `{"city":"台北"}`}}]}}]}
             {:choices [{:message {:role "assistant" :content "收到"}}]}))})

(def server (http/server (http/router {"/v1/chat/completions" fake-backend})
                         "127.0.0.1" port))

# ── 完整多輪 tool loop ──────────────────────────────────────────────
(def cfg (llm/endpoint "local" {:base (string "http://127.0.0.1:" port)}))
(def traced @[])
(def out (llm/with-tools cfg
                         @[@{:role "user" :content "台北天氣？"}]
                         llm/demo-tools
                         llm/demo-handlers
                         :trace (fn [n a r] (array/push traced n))))

(assert (= 2 (out :rounds)) "一輪要工具、一輪作答，共兩輪")
(assert (not (out :exhausted)) "沒撞到 max-rounds")
(assert (deep= @["get_weather"] traced) "trace 有被叫到")
(assert (string/has-prefix? "台北 " (out :text)) (string "最終答案不對：" (out :text)))
# 歷史：user → assistant(tool_calls) → tool → assistant
(assert (= 4 (length (out :messages))) "訊息歷史四則")
(assert (= "tool" (get-in out [:messages 2 :role])))
(assert (= "call_1" (get-in out [:messages 2 :tool_call_id])) "tool_call_id 要對得起來")
# ⚠ 工具回傳的 table 會被 json/encode 成字串，而 spork/json **把非 ASCII 逃逸成 \uXXXX**，
#   所以這裡驗 ASCII 的部分（是合法 JSON，對端解得開）。
(assert (string/find "\"temp_c\":31" seen-tool-result) "本地工具真的被執行了")

# max-rounds 防呆：假後端在沒有 tool 結果前一直要工具，把上限壓到 1 就該被擋下
(def out2 (llm/with-tools cfg @[@{:role "user" :content "x"}]
                          llm/demo-tools llm/demo-handlers :max-rounds 1))
(assert (out2 :exhausted) "撞到 max-rounds 要回報 exhausted")

# 沒宣告的工具名不該讓整條 loop 掛掉，而是把錯誤當工具結果送回去
(def out3 (llm/with-tools cfg @[@{:role "user" :content "x"}] llm/demo-tools {}))
(assert (string/find "沒有名為 get_weather 的工具" (get-in out3 [:messages 2 :content]))
        "缺 handler 要回錯誤字串給模型，不是丟例外")

# ── 自訂 endpoint 真的打得出去：直接指定 :url，繞過 base ────────────
(def direct-cfg (llm/endpoint {:model "my-model"
                               :url (string "http://127.0.0.1:" port "/v1/chat/completions")
                               :api-key "sk-test"
                               :headers {"x-my-header" "janet-lab"}   # ⚠ header 值請用 ASCII，見下面那條註解
                               :params {:temperature 0.2 :max_tokens 128}}))
(assert (= "收到" (llm/ask direct-cfg "嗨" nil nil :extra {:seed 7}))
        "inline endpoint 走完整條 HTTP 路徑")
(assert (= "my-model" (seen-payload :model)) "送出去的 model 是 endpoint 指定的")
(assert (= 0.2 (seen-payload :temperature)) "endpoint 的 :params 有進 payload")
(assert (= 128 (seen-payload :max_tokens)))
(assert (= 7 (seen-payload :seed)) ":extra 有進 payload")
(assert (= "Bearer sk-test" (seen-headers "authorization")) "自訂 api-key 有送出去")
(assert (= "janet-lab" (seen-headers "x-my-header")) "自訂 header 有送出去")
# ⚠ 實測：header 值放非 ASCII（中文）會讓 spork/http 的 server 回 400。
#   HTTP header 本來就只吃 ASCII／ISO-8859-1，要帶中文請放進 body 不要放 header。

# 呼叫端的具名參數蓋得掉 endpoint 的 :params（真的送到 wire 上）
(llm/ask direct-cfg "嗨" nil nil :temperature 1)
(assert (= 1 (seen-payload :temperature)) "具名參數 > endpoint 的 :params")

# ── 被 max_tokens 截斷：HTTP 200 但 content 是空的 ──────────────────
# ⚠ 實測（LM Studio + gemma-4-e4b）：推理模型會先花掉 reasoning tokens，
#   預算太小就 content=""、finish_reason="length"、HTTP 仍然 200。
(def trunc-res (llm/chat direct-cfg @[@{:role "user" :content "很長的問題"}] :max-tokens 8))
(assert (= "length" (llm/reply-finish-reason trunc-res)))
(assert (llm/truncated? trunc-res))
(assert (= "" (llm/reply-text trunc-res)) "content 真的是空字串，不是 nil")
# ask 承諾回答案，所以這種情況要講清楚而不是回 ""
(def e-trunc (u/err-of |(llm/ask direct-cfg "很長的問題" nil nil :max-tokens 8)))
(assert (string/find "finish_reason=length" e-trunc) (string "截斷訊息不對：" e-trunc))
(assert (string/find "reasoning tokens" e-trunc) "要點出推理模型吃掉預算這件事")
(assert (string/find "reasoning_tokens" e-trunc) "要把 usage 印出來")
# 沒截斷時 finish_reason 不是 length
(assert (not (llm/truncated? (llm/chat direct-cfg @[@{:role "user" :content "嗨"}]))))

# 連不上時的錯誤訊息要是中文、而且點得出 proxy 沒起來
(def e-conn (u/err-of |(llm/ask (llm/endpoint {:model "m" :base "http://127.0.0.1:45799"}) "嗨")))
(assert (string/find "連不上" e-conn) (string "連不上時的訊息不對：" e-conn))
(assert (string/find "127.0.0.1" e-conn))

(:close server)
(print "llm-http 假後端／tool loop 測試通過 ✓")
