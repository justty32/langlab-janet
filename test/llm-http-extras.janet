# llm-http：順手補的幾樣 —— response_format／ask-json、reply-usage、list-models、:retry。
#
# 全部離線：純函式的部分直接驗，要打 HTTP 的用同行程的假伺服器（會故意先回 503 再回 200）。

(import spork/http)
(import spork/json)
(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

# ── 純函式 ──────────────────────────────────────────────────────────
(def pcfg (llm/endpoint {:model "m"}))
(assert (deep= {:type "json_object"}
               ((llm/build-payload pcfg @[] :response-format {:type "json_object"}) :response_format))
        ":response-format 進 payload 的 response_format")
(def fmt (llm/json-schema-format "r" {:type "object" :properties {:a {:type "integer"}}}))
(assert (= "json_schema" (fmt :type)))
(assert (= true (get-in fmt [:json_schema :strict])))
(assert (deep= @{:a 1} (llm/parse-json-reply "{\"a\":1}")))
(assert (deep= @{:a 1} (llm/parse-json-reply "```json\n{\"a\":1}\n```")) "剝掉 ```json 圍欄")
(assert (deep= @[1 2] (llm/parse-json-reply "  [1,2]  ")))
(def e-json (u/err-of |(llm/parse-json-reply "我不想回 JSON")))
(assert (string/find "不是合法 JSON" e-json) e-json)
(assert (string/find "我不想回 JSON" e-json) "錯誤要附原文")
(assert (= 5 (get (llm/reply-usage {:usage {:total_tokens 5}}) :total_tokens)))
(assert (nil? (llm/reply-usage {:choices []})))
(assert (= "http://h/v1/models" (llm/models-url "http://h/v1/chat/completions")))
(assert (= "https://api.anthropic.com/v1/models" (llm/models-url "https://api.anthropic.com/v1/messages")))

# retry 的分類：只有連不上／5xx／429 才值得再試
(assert (llm/retryable? "連不上 http://x：refused"))
(assert (llm/retryable? "HTTP 503（http://x）：busy"))
(assert (llm/retryable? "HTTP 429（http://x）：slow down"))
(assert (not (llm/retryable? "HTTP 400（http://x）：bad")))
(assert (not (llm/retryable? "HTTP 401（http://x）：key")))
(assert (not (llm/retryable? "回應不是合法 JSON：x")))
(assert (= 503 (llm/error-status "HTTP 503（u）：x")))
(assert (< (llm/backoff-seconds 0 :base 0.1) 0.11))
(assert (<= (llm/backoff-seconds 9 :base 1 :cap 2) 2))

# ── 假伺服器：503 兩次再 200、json 模式、models ────────────────────
(def port 45761)
(var hits 0)
(var seen nil)
(defn- fake [req]
  (http/read-body req)
  (set seen (json/decode (string (or (req :body) "{}")) true))
  (case (req :path)
    "/v1/models"
    {:status 200 :headers {"content-type" "application/json"}
     :body (json/encode {:object "list" :data [{:id "local"} {:id "qwen"}]})}
    "/flaky/v1/chat/completions"
    (do (++ hits)
        (if (< hits 3)
          {:status 503 :headers {"content-type" "application/json"} :body `{"error":"暖機中"}`}
          {:status 200 :headers {"content-type" "application/json"}
           :body (json/encode {:choices [{:message {:role "assistant" :content "第三次才好"}}]})}))
    "/bad/v1/chat/completions"
    (do (++ hits) {:status 400 :headers {"content-type" "application/json"} :body `{"error":"參數錯"}`})
    {:status 200 :headers {"content-type" "application/json"}
     :body (json/encode {:choices [{:message {:role "assistant"
                                              :content (if (seen :response_format)
                                                         "```json\n{\"city\":\"台北\",\"n\":3}\n```"
                                                         "純文字")}}]
                         :usage {:prompt_tokens 4 :completion_tokens 6 :total_tokens 10}})}))
(def server (http/server fake "127.0.0.1" port))
(def base (string "http://127.0.0.1:" port))
(def cfg (llm/endpoint {:model "m" :base base}))

# ask-json：送了 response_format、拿回解好的 table
(def j (llm/ask-json cfg "台北" "只回 JSON"))
(assert (deep= @{:city "台北" :n 3} j) (string/format "ask-json：%q" j))
(assert (= "json_object" (get-in seen [:response_format :type])) "沒給 schema 走 json_object")
(llm/ask-json cfg "台北" nil nil :schema {:type "object"})
(assert (= "json_schema" (get-in seen [:response_format :type])) "給了 schema 走 json_schema")
(assert (= "reply" (get-in seen [:response_format :json_schema :name])))

# reply-usage 從真的回應拿
(assert (= 10 (get (llm/reply-usage (llm/chat cfg @[@{:role "user" :content "x"}])) :total_tokens)))

# list-models
(assert (deep= @["local" "qwen"] (map |($ :id) (llm/list-models cfg))))

# :retry —— 503 兩次後成功；退避用很小的 base 讓測試快
(set hits 0)
(def retried @[])
(def flaky (llm/endpoint {:model "m" :base (string base "/flaky")}))
(assert (= "第三次才好"
           (llm/ask flaky "嗨" nil nil :retry {:times 3 :base 0.01
                                              :on-retry (fn [n e w] (array/push retried n))})))
(assert (= 3 hits) "打了三次")
(assert (deep= @[1 2] retried) "重試回呼叫了兩次")
# 不給 :retry → 只打一次就丟
(set hits 0)
(assert (string/find "HTTP 503" (u/err-of |(llm/ask flaky "嗨"))))
(assert (= 1 hits))
# 次數用完仍失敗 → 把最後那個錯誤丟出來
(set hits 0)
(assert (string/find "暖機中" (u/err-of |(llm/ask flaky "嗨" nil nil :retry {:times 1 :base 0.01}))))
(assert (= 2 hits))
# 400 不重試
(set hits 0)
(assert (string/find "HTTP 400" (u/err-of |(llm/ask (llm/endpoint {:model "m" :base (string base "/bad")}) "嗨"
                                                    nil nil :retry {:times 5 :base 0.01}))))
(assert (= 1 hits) "400 不該重試")

(:close server)
(print "llm-http 結構化輸出／usage／models／retry 測試通過 ✓")
