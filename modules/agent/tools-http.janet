# http-get —— 讓模型抓一個網址的內容（只有 GET、只有 http://）。
#
# ⚠ spork/http 底層的 net/connect 沒有 TLS，所以 **https:// 一定打不通**。
#   這裡在送出去之前就先擋下來、回一句清楚的錯誤字串給模型（不是丟例外、也不是
#   真的去連——實測直接對 https 網址發 http 請求會拿到 cloudflare 的 400 頁面，模型會被誤導）。
#   真的要 https 請在外面架一個 http 的 proxy，或改用 curl 走 run-command。

(import spork/http)
(import ./registry :as reg)

(def http-max-bytes 8000)
(def http-timeout 10)

(def https-hint
  "回給模型的那句話；測試也比對這段，改字要一起改。"
  "錯誤：只支援 http:// 網址（spork/http 沒有 TLS，https:// 打不通）。請改用 http:// 的來源。")

(defn- clip [s n]
  (if (<= (length s) n) s (string (string/slice s 0 n) "\n…（已截斷，共 " (length s) " bytes）")))

(defn http-get
  ``抓一個網址，回 @{:status 狀態碼 :body 內容字串}。
  https:// 或不是 http:// 開頭的網址不會真的去連，直接丟例外（訊息就是 https-hint）。``
  [url &named timeout]
  (default timeout http-timeout)
  (def u (string (or url "")))
  (unless (string/has-prefix? "http://" u)
    (error https-hint))
  (def [ok res] (protect (ev/with-deadline timeout (http/request "GET" u))))
  (unless ok
    (error (string "抓不到 " u "：" res)))
  @{:status (res :status) :body (string (or (res :body) ""))})

(defn http-get-tool
  "包成工具：回「HTTP 狀態碼」加一行空白再接內容，內容超過 :max-bytes 會截斷。"
  [&named max-bytes timeout]
  (default max-bytes http-max-bytes)
  (reg/make-tool "http-get"
    "用 GET 抓一個網址的內容。只支援 http://（沒有 TLS，https:// 會回錯誤）。"
    {:type "object"
     :properties {:url {:type "string" :description "完整網址，http:// 開頭"}}
     :required ["url"]}
    (fn [args]
      (def r (http-get (get args :url) :timeout timeout))
      (string "HTTP " (r :status) "\n\n" (clip (r :body) max-bytes)))))
