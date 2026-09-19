# llm-http：Anthropic 原生 Messages API —— 雙向轉換的純函式驗證（不打網路）。
#
# 假伺服器跑完整 tool loop 那段在 llm-http-anthropic-loop.janet（本檔到 8 KB 上限拆出去的）。
# ⚠ 真打 api.anthropic.com 本機沒 key，未實測。

(import spork/json)
(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

# ── ① OpenAI → Anthropic（純函式）──────────────────────────────────
(def payload
  @{:model "claude-sonnet-5"
    :messages [@{:role "system" :content "你是助理"}
               @{:role "user" :content [@{:type "text" :text "看圖"}
                                        @{:type "image_url" :image_url @{:url "data:image/png;base64,QUJD"}}
                                        @{:type "image_url" :image_url @{:url "https://x/y.jpg"}}]}
               @{:role "assistant" :content "" :tool_calls [@{:id "t1" :type "function"
                                                              :function @{:name "f" :arguments "{\"a\":1}"}}]}
               @{:role "tool" :tool_call_id "t1" :content "結果一"}
               @{:role "tool" :tool_call_id "t2" :content "結果二"}]
    :tools [(llm/tool-spec "f" "說明" {:type "object" :properties {}})]
    :tool_choice "auto"
    :temperature 0.3
    :stop "END"
    :seed 7
    :response_format {:type "json_schema" :json_schema {:name "r" :schema {:type "object"}}}})
(def req (llm/to-anthropic payload))
(assert (= "你是助理" (req :system)) "system 抽到頂層")
(assert (= 4096 (req :max_tokens)) "max_tokens 必填，沒給就補預設")
(assert (nil? (req :seed)) "Anthropic 不認的欄位要丟掉")
(assert (= 0.3 (req :temperature)))
(assert (deep= ["END"] (req :stop_sequences)))
(assert (= 3 (length (req :messages))) "system 拿掉、兩則 tool 合成一則 user")
(def u0 (get-in req [:messages 0]))
(assert (= "user" (u0 :role)))
(assert (= "text" (get-in u0 [:content 0 :type])))
(assert (deep= {:type "base64" :media_type "image/png" :data "QUJD"} (get-in u0 [:content 1 :source]))
        "data URI 拆成 base64 source")
(assert (= "url" (get-in u0 [:content 2 :source :type])) "http URL 用 url source")
(def a1 (get-in req [:messages 1]))
(assert (= "assistant" (a1 :role)))
(assert (= "tool_use" (get-in a1 [:content 0 :type])) "content 空字串時不塞 text block")
(assert (deep= @{:a 1} (get-in a1 [:content 0 :input])) "arguments JSON 字串要 decode 成物件")
(def u2 (get-in req [:messages 2]))
(assert (= 2 (length (u2 :content))) "連續兩則 role=tool 合成同一則 user 的兩個 tool_result")
(assert (= "t2" (get-in u2 [:content 1 :tool_use_id])))
(assert (get-in req [:tools 0 :input_schema]) "tools 的 parameters 改名成 input_schema")
(assert (nil? (get-in req [:tools 0 :function])))
(assert (deep= {:type "auto"} (req :tool_choice)))
(assert (= "json_schema" (get-in req [:output_config :format :type])) "response_format → output_config")
(assert (nil? (req :response_format)))
# json_object 沒有對應：變成一句 system 提示
(def req2 (llm/to-anthropic @{:model "m" :messages [] :response_format {:type "json_object"}}))
(assert (string/find "JSON" (req2 :system)))

# ── ② Anthropic → OpenAI（純函式）──────────────────────────────────
(def res (llm/from-anthropic
           {:id "msg_1" :model "claude-sonnet-5" :stop_reason "tool_use"
            :content [{:type "text" :text "我查一下"}
                      {:type "tool_use" :id "toolu_1" :name "get_weather" :input {:city "台北"}}]
            :usage {:input_tokens 10 :output_tokens 5}}))
(assert (= "我查一下" (llm/reply-text res)))
(assert (= "tool_calls" (llm/reply-finish-reason res)))
(def tc (get-in (llm/reply-message res) [:tool_calls 0]))
(assert (= "toolu_1" (tc :id)))
(assert (= "get_weather" (get-in tc [:function :name])))
(assert (string? (get-in tc [:function :arguments])) "arguments 要是 JSON 字串（跟 OpenAI 一樣）")
(assert (deep= @{:city "台北"} (json/decode (get-in tc [:function :arguments]) true)))
(assert (= 15 (get (llm/reply-usage res) :total_tokens)))
(assert (= "length" (llm/reply-finish-reason (llm/from-anthropic {:stop_reason "max_tokens" :content []}))))
(assert (nil? (llm/reply-text (llm/from-anthropic {:stop_reason "tool_use"
                                                    :content [{:type "tool_use" :id "x" :name "f" :input {}}]})))
        "只有 tool_use 時 content 是 nil")
# 來回：轉回的 message 接回歷史再轉過去，要用原始 content（含任何 thinking block）
(def back (llm/to-anthropic @{:model "m" :messages [(llm/reply-message res)]}))
(assert (= 2 (length (get-in back [:messages 0 :content]))) "原樣送回原始 content block")

# ── ③ header 與 cfg ────────────────────────────────────────────────
(def direct (llm/endpoint "claude-direct" {:api-key "sk-ant-test"}))
(def hs (llm/anthropic-headers direct))
(assert (= "sk-ant-test" (hs "x-api-key")) "Anthropic 用 x-api-key 不是 Bearer")
(assert (nil? (hs "authorization")))
(assert (= "2023-06-01" (hs "anthropic-version")))
(assert (string/find "沒有金鑰" (u/err-of |(llm/anthropic-headers (llm/endpoint {:model "m" :api :anthropic}))))
        "沒設 key 要當場講清楚，不要等 401")
(assert (string/find ":api 只能是" (u/err-of |(llm/endpoint {:model "m" :api :gemini}))))

(print "llm-http Anthropic 原生轉換測試通過 ✓")
