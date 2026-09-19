# 模型列表 —— list-models：GET /v1/models，回模型物件的陣列。
#
# 網址從 cfg 的 :url 推：把結尾的 /chat/completions（或 Anthropic 的 /messages）換成 /models。
# 兩家的回應最外層都是 {"data": [{"id": …}, …]}，所以直接回 :data 那個陣列。
# ⚠ litellm proxy 回的是 yaml 裡的 model_name（local／deepseek…），不是 provider 的 model id。
# ⚠ Anthropic 的 /v1/models 走同一套 x-api-key header；本機沒 key，那條未實測。

(import ./transport :as tp)
(import ./provider-anthropic :as anth)

(defn models-url
  "從 chat 網址推出 models 網址。"
  [url]
  (def u (string url))
  (cond
    (string/has-suffix? "/chat/completions" u)
    (string (string/slice u 0 (- (length u) (length "/chat/completions"))) "/models")
    (string/has-suffix? "/messages" u)
    (string (string/slice u 0 (- (length u) (length "/messages"))) "/models")
    (string/has-suffix? "/" u) (string u "models")
    (string u "/models")))

(defn list-models
  ``列出這個 endpoint 那端有哪些模型，回模型物件的陣列（每個至少有 :id）。
  想要純 id 的清單：(map |($ :id) (list-models cfg))。``
  [cfg]
  (def url (models-url (or (cfg :url) "")))
  (def headers (if (anth/anthropic? cfg) (anth/anthropic-headers cfg) nil))
  (def res (tp/request-json cfg "GET" url nil headers))
  (def data (get res :data))
  (unless (indexed? data)
    (error (string "回應裡沒有 data 陣列：" (string/format "%q" res))))
  data)
