# 傳輸層 —— 只做「把 payload POST 出去、把回應解成 Janet 資料」這一件事。
#
# 這一層不認識 messages／tools／圖片，也不印任何東西、不 os/exit；
# 出錯一律 (error "中文訊息")，要怎麼呈現交給 cli.janet 決定。
# 上面那層（對話語意：chat／ask／取答案）在 chat.janet。
#
# ★ 為什麼可以純 Janet：目標是本機的 litellm proxy，走 **http 不是 https**，
#   spork/http 底層的 net/connect 沒有 TLS，但 http 這條路它自己就夠了。
#   （所以 :url 指到 https:// 的外部伺服器是打不通的，不是設定寫錯。）
#
# ★ 兩個容易踩的點（實測）：
#   1. (res :body) 是 **buffer**，丟給 json/decode 前要先 (string …) 包一層。
#   2. json/decode 第二個參數給 true，key 才會變成 keyword（否則是字串，get-in 全部落空）。

(import spork/http)
(import spork/json)
(import ./defaults :as d)

(defn headers-for
  ``組 request header。

  預設兩個：content-type 與 Authorization: Bearer <api-key>。
  cfg 的 :headers 會疊在上面，**同名以使用者的為準**（key 一律轉小寫比對，
  所以自訂 "Authorization" 蓋得掉預設那個）。``
  [cfg]
  (def h @{"content-type" "application/json"})
  (when (cfg :api-key)
    (put h "authorization" (string "Bearer " (cfg :api-key))))
  (when-let [extra (cfg :headers)]
    (eachp [k v] extra
      (put h (string/ascii-lower (string k)) (string v))))
  h)

(defn post-chat
  ``把 payload POST 到 chat completions 端點，回傳解好的 JSON（key 是 keyword）。

  cfg 至少要有 :url；沒有就用 defaults/chat-url 的預設值。
  連不上、非 2xx、回應不是 JSON —— 三種都丟例外，訊息都是中文的。``
  [cfg payload]
  (def url (or (cfg :url) (d/chat-url)))
  (def [ok res]
    (protect (http/request "POST" url
                           :body (json/encode payload)
                           :headers (headers-for cfg))))
  (unless ok
    (error (string "連不上 " url "：" res
                   "\n（litellm proxy／LM Studio 起來了嗎？位址一定要用 127.0.0.1 不要用 localhost；"
                   "spork/http 沒有 TLS，https:// 打不通）")))

  # ★ :body 是 buffer，要 string 包一層
  (def text (string (or (res :body) "")))
  (def status (res :status))
  (unless (and status (<= 200 status 299))
    (error (string/format "HTTP %q（%s）：%s" status url (string/trim text))))

  # ★ 第二參 true → JSON 的 key 變 keyword
  (def [ok2 payload2] (protect (json/decode text true)))
  (unless ok2
    (error (string "回應不是合法 JSON：" (string/trim text))))
  payload2)
