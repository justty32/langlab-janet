# 傳輸層 —— HTTP 收送與 JSON 編解碼，加上取答案的小工具。
#
# 這一層只做「把 payload POST 出去、把回應解成 Janet 資料」。不印任何東西、不 os/exit；
# 出錯一律 (error "…")，要怎麼呈現交給 main.janet 決定。
#
# ★ 為什麼可以純 Janet：目標是本機的 litellm proxy，走 **http 不是 https**，
#   spork/http 底層的 net/connect 沒有 TLS，但 http 這條路它自己就夠了。
#
# ★ 兩個容易踩的點（實測）：
#   1. (res :body) 是 **buffer**，丟給 json/decode 前要先 (string …) 包一層。
#   2. json/decode 第二個參數給 true，key 才會變成 keyword（否則是字串，get-in 全部落空）。

(import spork/http)
(import spork/json)
(import ./endpoints :as ep)
(import ./media)

(defn- headers-for
  "組 request header。proxy 一律走 Authorization: Bearer。"
  [cfg]
  (def h @{"content-type" "application/json"})
  (when (cfg :api-key)
    (put h "authorization" (string "Bearer " (cfg :api-key))))
  h)

(defn post-chat
  ``把 payload POST 到 /v1/chat/completions，回傳解好的 JSON（key 是 keyword）。

  cfg 至少要有 :url；沒有就用 endpoints/chat-url 的預設值。
  連不上、非 2xx、回應不是 JSON —— 三種都丟例外。``
  [cfg payload]
  (def url (or (cfg :url) (ep/chat-url)))
  (def [ok res]
    (protect (http/request "POST" url
                           :body (json/encode payload)
                           :headers (headers-for cfg))))
  (unless ok
    (error (string "連不上 " url "：" res "\n（litellm proxy 起來了嗎？位址一定要用 127.0.0.1 不要用 localhost）")))

  # ★ :body 是 buffer，要 string 包一層
  (def text (string (or (res :body) "")))
  (def status (res :status))
  (unless (and status (<= 200 status 299))
    (error (string/format "HTTP %q：%s" status (string/trim text))))

  # ★ 第二參 true → JSON 的 key 變 keyword
  (def [ok2 payload2] (protect (json/decode text true)))
  (unless ok2
    (error (string "回應不是合法 JSON：" (string/trim text))))
  payload2)

(defn chat
  ``打一次 chat completion。messages 是 OpenAI 格式的訊息陣列，回傳整份解好的回應。

  具名參數（都可省略）：
    :tools       OpenAI 格式的 tool 宣告陣列
    :tool-choice "auto"／"none"／指定某個 tool
    :temperature :max-tokens
    :extra       一張 table，原樣併進 payload（想送 proxy 認得的其他欄位時用）

  ⚠ OpenRouter 那條線特別注意：不同模型的 supported_parameters 不一樣，
    送了它不支援的參數（response_format／top_p／seed…）**不會報錯，就是被無視**，
    你會拿到 exit 0 加一份看起來像答案的東西。要確認只能看回應內容對不對。``
  [cfg messages &named tools tool-choice temperature max-tokens extra]
  (assert (cfg :model) "endpoint 設定缺 :model")
  (def payload @{:model (cfg :model) :messages messages})
  (when tools       (put payload :tools tools))
  (when tool-choice (put payload :tool_choice tool-choice))
  (when temperature (put payload :temperature temperature))
  (when max-tokens  (put payload :max_tokens max-tokens))
  (when extra (eachp [k v] extra (put payload k v)))
  (post-chat cfg payload))

(defn reply-message
  "從回應取出 assistant 那則訊息（含 :content 與可能的 :tool_calls）；取不到回 nil。"
  [res]
  (get-in res [:choices 0 :message]))

(defn reply-text
  "從回應取出答案文字；取不到回 nil（例如模型只回了 tool_calls）。"
  [res]
  (get-in res [:choices 0 :message :content]))

(defn ask
  ``最常用的一行式問答：給 prompt，拿字串答案回來。

  system —— 可省略的 system 訊息。
  images —— 可省略的圖檔路徑／URL 陣列；有給就自動把 user 訊息換成 parts 形狀。
            ⚠ 記得挑吃圖的 endpoint（見 endpoints/specs 的 :vision?）。``
  [cfg prompt &opt system images]
  (def messages @[])
  (when (and system (not (empty? system)))
    (array/push messages @{:role "system" :content system}))
  (array/push messages (media/user-message prompt images))
  (def res (chat cfg messages))
  (def text (reply-text res))
  (unless (string? text)
    (error (string "回應裡取不出答案文字：" (string/format "%q" res))))
  text)
