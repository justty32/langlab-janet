# modules/llm-http 的離線測試。
#
# 不碰真的 LLM：起一台**假的 OpenAI 相容後端**（spork/http 的 server 就在同一個行程裡，
# 靠 ev loop 跟 client 併行），拿它把整條 tool loop 走一遍。
# 純函式（endpoint 表、圖像 parts、tool-spec）則直接驗。

(import spork/http)
(import spork/json)
(import ../modules/llm-http/init :as llm)

# ── endpoint 設定表 ─────────────────────────────────────────────────
(assert (deep= @["claude" "deepseek" "local" "openrouter"] (llm/endpoint-names))
        "四個 endpoint 都在")

(def local (llm/endpoint "local"))
(assert (= "local" (local :model)))
(assert (string/has-prefix? "http://127.0.0.1:" (local :url)) "預設 base 是 127.0.0.1")
(assert (string/has-suffix? "/v1/chat/completions" (local :url)))
(assert (local :vision?) "local 指到 gemma-4，吃圖")
(assert (not ((llm/endpoint "deepseek") :vision?)) "deepseek 純文字")
(assert (= "ANTHROPIC_API_KEY" ((llm/endpoint "claude") :env)))
(assert (= "OPENROUTER_API_KEY" ((llm/endpoint "openrouter") :env)))
(assert (nil? (llm/endpoint "沒這個")))

# overrides：換 model、換 base，而且不污染下一次
(assert (= "qwen" ((llm/endpoint "local" {:model "qwen"}) :model)))
(assert (= "local" ((llm/endpoint "local") :model)) "overrides 不污染下一次")
(assert (= "http://127.0.0.1:9999/v1/chat/completions"
           ((llm/endpoint "local" {:base "http://127.0.0.1:9999"}) :url)))

# 不需要金鑰的 endpoint 一律 ready
(assert (llm/env-ready? "local"))

# ── 圖像輸入（vision）─────────────────────────────────────────────
(assert (= "image/png"  (llm/mime-for-path "/tmp/a.PNG")))
(assert (= "image/jpeg" (llm/mime-for-path "/tmp/a.jpg")))
(assert (= "image/webp" (llm/mime-for-path "/tmp/a.webp")))

# 沒給圖 → content 還是字串（最常用的路徑保持乾淨）
(def m-plain (llm/user-message "嗨"))
(assert (= "嗨" (m-plain :content)) "純文字時 content 是字串")

# 有給圖 → content 變 parts 陣列，文字在前、圖在後
(def m-img (llm/user-message "這是什麼" ["https://example.com/a.png"]))
(assert (indexed? (m-img :content)) "帶圖時 content 是陣列")
(assert (= "text" (get-in m-img [:content 0 :type])))
(assert (= "image_url" (get-in m-img [:content 1 :type])))
(assert (= "https://example.com/a.png" (get-in m-img [:content 1 :image_url :url])))

# 本機檔案 → data URI（拿本測試檔自己當 bytes 來源，不必另外造檔）
(def uri (llm/data-uri (dyn :current-file) "image/png"))
(assert (string/has-prefix? "data:image/png;base64," uri) "data URI 前綴")

# ── tool 宣告 ───────────────────────────────────────────────────────
(def spec (llm/tool-spec "echo" "回聲" {:type "object" :properties {}}))
(assert (= "function" (spec :type)))
(assert (= "echo" (get-in spec [:function :name])))
(assert (= 2 (length llm/demo-tools)) "示範工具有兩個")

# ── 假後端 ＋ 完整多輪 tool loop ────────────────────────────────────
# 規則：訊息歷史裡還沒出現 role="tool" → 回一則 tool_calls；出現了 → 拿它的內容作答。
(def port 45711)
(var seen-tool-result nil)

(defn- fake-backend [req]
  (http/read-body req)
  (def body (json/decode (string (or (req :body) "{}")) true))
  (def tool-msg (find |(= "tool" (get $ :role)) (body :messages)))
  (when tool-msg (set seen-tool-result (get tool-msg :content)))
  {:status 200
   :headers {"content-type" "application/json"}
   :body (json/encode
           (if tool-msg
             {:choices [{:message {:role "assistant"
                                   :content (string "台北 " (get tool-msg :content))}}]}
             {:choices [{:message {:role "assistant"
                                   :tool_calls [{:id "call_1"
                                                 :type "function"
                                                 :function {:name "get_weather"
                                                            :arguments `{"city":"台北"}`}}]}}]}))})

(def server (http/server (http/router {"/v1/chat/completions" fake-backend})
                         "127.0.0.1" port))

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

(:close server)
(print "modules/llm-http 離線測試通過 ✓")
