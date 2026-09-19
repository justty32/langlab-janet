# llm-http：Anthropic 原生 Messages API —— 假伺服器模擬 Anthropic 回應形狀，跑一整輪 tool loop。
#
# 驗的是「OpenAI 形狀進、Anthropic 形狀出、再轉回 OpenAI 形狀」之後 with-tools 一行不用改：
# system 抽到頂層、tools 變 input_schema、tool_result 包在 user 訊息、thinking block 原樣送回。
# 純函式的雙向轉換在 llm-http-anthropic.janet。⚠ 真打 api.anthropic.com 本機沒 key，未實測。

(import spork/http)
(import spork/json)
(import ../modules/llm-http/init :as llm)

(llm/reset-endpoints!)

# ── ④ 假 Anthropic 伺服器跑一整輪 tool loop ────────────────────────
(def port 45741)
(var seen nil)
(defn- fake-anthropic [req]
  (http/read-body req)
  (def body (json/decode (string (req :body)) true))
  (set seen [(req :headers) body])
  (def last-msg (last (body :messages)))
  (def has-result (and (indexed? (last-msg :content))
                       (= "tool_result" (get-in last-msg [:content 0 :type]))))
  {:status 200 :headers {"content-type" "application/json"}
   :body (json/encode
           (if has-result
             {:id "m2" :model "claude-sonnet-5" :stop_reason "end_turn"
              :content [{:type "text" :text (string "台北 " (get-in last-msg [:content 0 :content]))}]
              :usage {:input_tokens 20 :output_tokens 8}}
             {:id "m1" :model "claude-sonnet-5" :stop_reason "tool_use"
              :content [{:type "thinking" :thinking "" :signature "sig"}
                        {:type "tool_use" :id "toolu_1" :name "get_weather" :input {:city "台北"}}]
              :usage {:input_tokens 10 :output_tokens 5}}))})
(def server (http/server (http/router {"/v1/messages" fake-anthropic}) "127.0.0.1" port))
(def cfg (llm/endpoint "claude-direct" {:api-key "sk-ant-test" :transport :http
                                        :url (string "http://127.0.0.1:" port "/v1/messages")}))
(def out (llm/with-tools cfg @[@{:role "user" :content "台北天氣？"}] llm/demo-tools llm/demo-handlers
                         :system "用中文"))
(assert (= 2 (out :rounds)))
(assert (string/has-prefix? "台北 " (out :text)) (string "最終答案：" (out :text)))
(assert (= "用中文" (get-in seen [1 :system])) "system 送到頂層")
(assert (= "sk-ant-test" (get-in seen [0 "x-api-key"])))
(assert (get-in seen [1 :tools 0 :input_schema]) "wire 上的 tools 是 Anthropic 形狀")
# 第二輪送回去的 assistant 訊息要原樣帶 thinking block
(def sent-assistant (get-in seen [1 :messages 1]))
(assert (= "thinking" (get-in sent-assistant [:content 0 :type])) "thinking block 原樣送回")
(assert (= "tool_result" (get-in seen [1 :messages 2 :content 0 :type])))
(assert (string/find "temp_c" (get-in seen [1 :messages 2 :content 0 :content])) "工具結果真的送回去了")
(assert (= "user" (get-in seen [1 :messages 2 :role])) "tool_result 包在 user 訊息裡")
(def one (llm/chat cfg @[@{:role "user" :content "x"}]))
(assert (= 15 (get (llm/reply-usage one) :total_tokens)) "usage 轉成 OpenAI 欄位名（10+5）")
(assert (= 10 (get (llm/reply-usage one) :prompt_tokens)))

(:close server)
(print "llm-http Anthropic 假伺服器 tool loop 測試通過 ✓")
