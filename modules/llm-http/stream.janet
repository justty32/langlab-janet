# 串流（SSE）—— chat-stream／ask-stream：送 stream:true，邊收邊叫 on-delta，最後回合併好的回應。
#
# 傳輸選了兩條，理由寫在各自檔頭：
#   http://  → stream-http.janet   net/connect ＋ 手寫 HTTP/1.1（spork 的 http/request 只讀第一個事件）
#   https:// → stream-curl.janet   curl -N 逐段讀 stdout
# 解析與合併是同一套（sse.janet／stream-anthropic.janet），所以兩條傳輸長出來的回應一樣。
#
# 合併後的回應跟 chat 回的**同形狀**：reply-text／reply-message／reply-finish-reason／
# reply-usage 都直接吃；多一個 :chunks 記這次收了幾個事件。
#
# ⚠ usage 在 OpenAI 相容端點要送 stream_options.include_usage=true 才會出現在最後一塊
#   （LM Studio／litellm 都認；不認的伺服器用 :include-usage false 關掉）。
# ⚠ 串流時 HTTP 200 一樣不代表講完——finish_reason 還是要看。

(import spork/json)
(import ./chat :as conv)
(import ./media)
(import ./transport :as tp)
(import ./provider-anthropic :as anth)
(import ./sse)
(import ./stream-anthropic :as sa)
(import ./stream-http :as sh)
(import ./stream-curl :as sc)

(defn chat-stream
  ``跟 chat 一樣的參數，多了：
    :on-delta      (fn [text]) 每收到一段答案文字就叫一次
    :on-event      (fn [event]) 每個解好的 SSE 事件都叫一次（debug 用，可省略）
    :include-usage 預設 true；OpenAI 相容端點會多送 stream_options.include_usage
  回合併後的回應（跟 chat 同形狀）。``
  [cfg messages &named on-delta on-event include-usage tools tool-choice
                       temperature max-tokens top-p extra params response-format]
  (default include-usage true)
  (def payload (conv/build-payload cfg messages
                                   :tools tools :tool-choice tool-choice
                                   :temperature temperature :max-tokens max-tokens
                                   :top-p top-p :extra extra :params params
                                   :response-format response-format))
  (put payload :stream true)
  (def anth? (anth/anthropic? cfg))
  (when (and include-usage (not anth?) (nil? (payload :stream_options)))
    (put payload :stream_options {:include_usage true}))
  (def url     (if anth? (anth/anthropic-url cfg) (or (cfg :url) (error "cfg 缺 :url"))))
  (def headers (if anth? (anth/anthropic-headers cfg) (tp/headers-for cfg)))
  (def body    (string (json/encode (if anth? (anth/to-anthropic payload) payload))))
  (def merger  (if anth? (sa/make-anthropic-merger on-delta) (sse/make-openai-merger on-delta)))
  (def consume (sse/make-sse-consumer
                 (fn [ev] (when on-event (on-event ev)) ((merger :feed) ev))))
  (def split   (sse/make-line-splitter consume))
  (if (tp/use-curl? cfg url)
    (sc/stream-post url headers body split (cfg :timeout))
    (sh/stream-post url headers body split))
  (split nil)
  ((merger :finish)))

(defn ask-stream
  ``一行式的串流問答：邊印邊收，最後回完整答案字串。

  參數跟 ask 一樣（prompt、可省略的 system／images、具名參數）。
  :on-delta 沒給就用預設的「印到 stdout 並 flush」，而且收完會補一個換行；
  給了就完全交給你（不補換行）。``
  [cfg prompt &opt system images &named on-delta temperature max-tokens top-p extra params
                                        response-format]
  (def default? (nil? on-delta))
  (def printer (or on-delta (fn [t] (prin t) (flush))))
  (def messages @[])
  (when (and system (not (empty? system)))
    (array/push messages @{:role "system" :content system}))
  (array/push messages (media/user-message prompt images))
  (def res (chat-stream cfg messages :on-delta printer
                        :temperature temperature :max-tokens max-tokens :top-p top-p
                        :extra extra :params params :response-format response-format))
  (when default? (print))
  (def text (conv/reply-text res))
  (unless (string? text)
    (error (string "串流回應裡取不出答案文字：" (string/format "%q" res))))
  text)
