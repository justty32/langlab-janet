# agent 測試共用：一台**假的 OpenAI 相容後端**，跑在同一個行程裡（照 llm-http-server.janet 的做法）。
#
# ⚠ jpm test 會把 test/ 底下每一支 .janet 都當測試跑，所以這支**只能有定義**，
#   不能有會印東西或起伺服器的頂層程式碼（跟 util.janet 同一條規矩）。
#
# 用法：
#   (def srv (fake/start! 45721 fake/standard-backend))
#   … 跑 agent，endpoint 給 {:model "m" :base "http://127.0.0.1:45721"} …
#   (:close srv)
#
# standard-backend 的腳本：
#   ① 最後一則 user 之後有 role="tool" 的訊息 → 回「工具說：<所有 tool 內容用 | 接起來>」
#   ② 沒有，但這次帶了 :tools → 要求叫 calc（帶 1+2*3）；沒有 calc 就叫第一個工具（空參數）
#   ③ 兩者皆非 → 回「收到：<最後一則 user 的內容>」
#   每次都附 usage {prompt 10, completion 5}，測 usage 累計用。

(import spork/http)
(import spork/json)

(def seen
  "每一次請求的 payload（解成 keyword key 的 table），測試拿來驗送出去的東西。"
  @[])

(def usage-per-call {:prompt_tokens 10 :completion_tokens 5 :total_tokens 15})

(defn reply
  "一則純文字回應。"
  [content &opt usage]
  {:choices [{:finish_reason "stop" :message {:role "assistant" :content content}}]
   :usage (or usage usage-per-call)})

(defn tool-call
  "一個 tool_call 物件；args 給 table，會 encode 成 JSON 字串（跟真後端一樣）。"
  [id name args]
  {:id id :type "function" :function {:name name :arguments (json/encode args)}})

(defn reply-tools
  "一則要求工具的回應。"
  [calls &opt usage]
  {:choices [{:finish_reason "tool_calls"
              :message {:role "assistant" :content nil :tool_calls calls}}]
   :usage (or usage usage-per-call)})

(defn- last-user-index [msgs]
  (var idx -1)
  (eachp [i m] msgs (when (= "user" (get m :role)) (set idx i)))
  idx)

(defn tool-results-after-last-user
  "最後一則 user 之後所有 role=\"tool\" 的內容。"
  [msgs]
  (def from (inc (last-user-index msgs)))
  (seq [m :in (array/slice msgs from) :when (= "tool" (get m :role))] (string (get m :content))))

(defn last-user-text [msgs]
  (def m (get msgs (last-user-index msgs)))
  (def c (get m :content))
  (if (indexed? c) (string/join (map |(string (get $ :text "")) c) "") (string c)))

(defn standard-backend
  "見檔頭的腳本。body 是解好的 payload。"
  [body]
  (def msgs (body :messages))
  (def results (tool-results-after-last-user msgs))
  (def tool-names (map |(get-in $ [:function :name]) (or (body :tools) [])))
  (cond
    (not (empty? results))
    (reply (string "工具說：" (string/join results " | ")))

    (not (empty? tool-names))
    (if (index-of "calc" tool-names)
      (reply-tools [(tool-call "call_1" "calc" {:expression "1+2*3"})])
      (reply-tools [(tool-call "call_1" (first tool-names) {})]))

    (reply (string "收到：" (last-user-text msgs)))))

(defn start!
  "起一台假後端在 127.0.0.1:port，/v1/chat/completions 交給 backend。回 server（用 :close 關）。"
  [port backend]
  (defn handler [req]
    (http/read-body req)
    (def body (json/decode (string (or (req :body) "{}")) true))
    (array/push seen body)
    {:status 200
     :headers {"content-type" "application/json"}
     :body (json/encode (backend body))})
  (http/server (http/router {"/v1/chat/completions" handler}) "127.0.0.1" port))

(defn endpoint-spec
  "對著這台假後端的 endpoint 設定。"
  [port]
  {:model "fake" :base (string "http://127.0.0.1:" port)})
