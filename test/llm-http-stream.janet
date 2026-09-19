# llm-http：串流（SSE）—— 假伺服器回 SSE（含分片的 tool_calls），驗兩條傳輸都合得對。
#
# 假後端用 spork/http 的 server，body 給一個 **coro**（不是字串）→ spork 就走 chunked
# 逐塊送，中間 ev/sleep 一下，逼客戶端真的「邊收邊解」而不是一次拿到整份。
# 兩條傳輸：http:// 走 net/connect（stream-http），:transport :curl 走 curl -N（stream-curl）；
# curl 不在 PATH 就跳過那一段並印原因。

(import spork/http)
(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)
(def port 45731)

(def text-events
  ["data: {\"id\":\"c1\",\"model\":\"m\",\"choices\":[{\"index\":0,\"delta\":{\"role\":\"assistant\",\"content\":\"\"}}]}\n\n"
   "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"你\"}}]}\n\n"
   ": ping\n\n"
   "data: {\"choices\":[{\"index\":0,\"delta\":{\"content\":\"好\"}}]}\n\n"
   "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"stop\"}]}\n\n"
   "data: {\"choices\":[],\"usage\":{\"prompt_tokens\":3,\"completion_tokens\":2,\"total_tokens\":5}}\n\n"
   "data: [DONE]\n\n"])

(def tool-events
  ["data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"id\":\"call_1\",\"type\":\"function\",\"function\":{\"name\":\"get_\",\"arguments\":\"\"}}]}}]}\n\n"
   "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"name\":\"weather\",\"arguments\":\"{\\\"city\\\":\"}}]}}]}\n\n"
   "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":0,\"function\":{\"arguments\":\"\\\"台北\\\"}\"}}]}}]}\n\n"
   "data: {\"choices\":[{\"index\":0,\"delta\":{\"tool_calls\":[{\"index\":1,\"id\":\"call_2\",\"function\":{\"name\":\"now\",\"arguments\":\"{}\"}}]}}]}\n\n"
   "data: {\"choices\":[{\"index\":0,\"delta\":{},\"finish_reason\":\"tool_calls\"}]}\n\n"
   "data: [DONE]\n\n"])

(var seen-payload nil)
(defn- fake-sse [req]
  (http/read-body req)
  (set seen-payload (string (req :body)))
  (cond
    (= "/err" (req :path))
    {:status 429 :headers {"content-type" "application/json"} :body `{"error":"太多了"}`}
    {:status 200
     :headers {"content-type" "text/event-stream"}
     # ★ 給 coro → chunked 逐塊送；sleep 讓客戶端一定會分好幾次收到
     :body (coro (each e (if (string/find "\"tools\"" seen-payload) tool-events text-events)
                   (yield e) (ev/sleep 0.005)))}))

# ⚠ 不用 http/router：它只認註冊過的路徑，/err 那條會被它先擋成 404
(def server (http/server fake-sse "127.0.0.1" port))
(def base (string "http://127.0.0.1:" port))

(defn check-transport [label cfg]
  (def deltas @[])
  (def res (llm/chat-stream cfg @[@{:role "user" :content "嗨"}]
                            :on-delta (fn [t] (array/push deltas t))))
  (assert (deep= @["你" "好"] deltas) (string label "：on-delta 每段都叫到"))
  (assert (= "你好" (llm/reply-text res)) (string label "：content 合起來"))
  (assert (= "stop" (llm/reply-finish-reason res)))
  (assert (= 5 (get (llm/reply-usage res) :total_tokens)) (string label "：最後那塊的 usage 有收到"))
  (assert (= "c1" (res :id)))
  (assert (>= (res :chunks) 5))
  (assert (string/find "\"stream\":true" seen-payload) "payload 真的送了 stream:true")
  (assert (string/find "include_usage" seen-payload) "預設送 stream_options.include_usage")

  # tool_calls 分片：name 與 arguments 都要接起來、兩個 call 依 index 分開
  (def res2 (llm/chat-stream cfg @[@{:role "user" :content "天氣"}] :tools llm/demo-tools))
  (def msg (llm/reply-message res2))
  (assert (nil? (msg :content)) "只有 tool_calls 時 content 是 nil（跟 OpenAI 一樣）")
  (assert (= 2 (length (msg :tool_calls))))
  (assert (= "get_weather" (get-in msg [:tool_calls 0 :function :name])) "name 分兩塊要接起來")
  (assert (= "{\"city\":\"台北\"}" (get-in msg [:tool_calls 0 :function :arguments])) "arguments 三塊接起來")
  (assert (= "call_2" (get-in msg [:tool_calls 1 :id])))
  (assert (= "tool_calls" (llm/reply-finish-reason res2)))

  # ask-stream：自訂 on-delta 時不補換行，回完整字串
  (def got @"")
  (assert (= "你好" (llm/ask-stream cfg "嗨" nil nil :on-delta (fn [t] (buffer/push got t)))))
  (assert (= "你好" (string got)))

  # 非 2xx：中文錯誤、帶狀態碼與伺服器原文
  (def e (u/err-of |(llm/chat-stream (llm/endpoint cfg {:url (string base "/err")}) @[@{:role "user" :content "x"}])))
  (assert (string/find "HTTP 429" e) (string label "：狀態碼要在錯誤裡：" e))
  (assert (string/find "太多了" e) (string label "：伺服器原文要在錯誤裡")))

# ── ① http://，純 Janet 那條（net/connect ＋ 手寫 chunked 解析）────────
(check-transport "stream-http" (llm/endpoint {:model "m" :base base}))

# ── ② 同一台假伺服器，改走 curl -N ───────────────────────────────────
(if (llm/curl-available?)
  (check-transport "stream-curl" (llm/endpoint {:model "m" :base base :transport :curl}))
  (print "（跳過 curl 串流那段：這台機器 PATH 上沒有 curl）"))

# ── ③ 純函式：line splitter 跨 chunk 邊界 ────────────────────────────
(def lines @[])
(def feed (llm/make-line-splitter |(array/push lines $)))
(feed "ab\r\nc") (feed "d\n\nef") (feed nil)
(assert (deep= @["ab" "cd" "" "ef"] lines) "跨段切行、去 \\r、結尾殘段也吐出")

(:close server)
(print "llm-http 串流測試通過 ✓")
