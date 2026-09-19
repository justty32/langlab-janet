# 傳輸層 —— 只做「把 payload POST 出去、把回應解成 Janet 資料」這一件事。
#
# 這一層不認識 messages／tools／圖片，也不印任何東西、不 os/exit；
# 出錯一律 (error "中文訊息")，要怎麼呈現交給 cli.janet 決定。
# 上面那層（對話語意：chat／ask／取答案）在 chat.janet。
#
# ── 兩條傳輸路，自動選 ──────────────────────────────────────────────
#   spork/http  純 Janet，http:// 專用（本機 litellm proxy／LM Studio）
#   curl        子行程，https:// 也通（直打 Anthropic／OpenAI／DeepSeek），見 transport-curl.janet
#   選路規則（use-curl?）：cfg 給 :transport :curl，**或** :url 以 https:// 開頭 → curl；否則 spork/http。
#
# ★ 為什麼 spork/http 只能 http：底層的 net/connect 沒有 TLS。
#   （以前 :url 指到 https:// 是打不通的；現在會自動改走 curl。）
#
# ★ 兩個容易踩的點（實測）：
#   1. (res :body) 是 **buffer**，丟給 json/decode 前要先 (string …) 包一層。
#   2. json/decode 第二個參數給 true，key 才會變成 keyword（否則是字串，get-in 全部落空）。

(import spork/http)
(import spork/json)
(import ./defaults :as d)
(import ./transport-curl :as curl)

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

(defn use-curl?
  "這份 cfg 打這個 url 該不該走 curl：明講 :transport :curl，或 url 是 https://。"
  [cfg &opt url]
  (def u (string (or url (cfg :url) "")))
  (or (= :curl (cfg :transport))
      (string/has-prefix? "https://" u)))

(defn- decode-json
  [text]
  (def [ok v] (protect (json/decode text true)))
  (unless ok
    (error (string "回應不是合法 JSON：" (string/trim text))))
  v)

(defn- spork-json
  "spork/http 那條：送 JSON、收 JSON。"
  [method url headers &opt payload]
  (def [ok res]
    (protect (http/request method url
                           :body (when payload (json/encode payload))
                           :headers headers)))
  (unless ok
    (error (string "連不上 " url "：" res
                   "\n（litellm proxy／LM Studio 起來了嗎？位址一定要用 127.0.0.1 不要用 localhost）")))
  # ★ :body 是 buffer，要 string 包一層
  (def text (string (or (res :body) "")))
  (def status (res :status))
  (unless (and status (<= 200 status 299))
    (error (string/format "HTTP %q（%s）：%s" status url (string/trim text))))
  (decode-json text))

(defn request-json
  ``送一個 JSON request 到 url、回解好的 JSON（key 是 keyword），依 use-curl? 自動選路。

  headers 沒給就用 headers-for；payload 是 nil 時不送 body（GET 用）。
  連不上、非 2xx、回應不是 JSON —— 三種都丟例外，訊息都是中文的。``
  [cfg method url &opt payload headers]
  (def h (or headers (headers-for cfg)))
  (if (use-curl? cfg url)
    (curl/curl-json method url h payload (cfg :timeout))
    (spork-json method url h payload)))

(defn post-chat
  ``把 payload POST 到 chat completions 端點，回傳解好的 JSON（key 是 keyword）。

  cfg 至少要有 :url；沒有就用 defaults/chat-url 的預設值。
  ⚠ 這一支只認 OpenAI 相容格式；:api :anthropic 的轉換在 dispatch.janet／provider-anthropic.janet。``
  [cfg payload]
  (request-json cfg "POST" (or (cfg :url) (d/chat-url)) payload))
