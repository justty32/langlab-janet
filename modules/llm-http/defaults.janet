# 預設值層 —— 「沒特別指定時要打哪、用什麼金鑰」就這一件事。
#
# 這裡刻意**不**認識任何 endpoint：它只知道「預設的 proxy 在哪」與「怎麼把 base 組成
# chat completions 的完整網址」。endpoint 的資料在 builtin.janet，registry 行為在
# registry.janet，設定檔在 config.janet。
#
# ★ 這一層是唯一會讀 LITELLM_BASE／LITELLM_API_KEY 兩個環境變數的地方。

(def default-base
  "litellm proxy 的預設位址。⚠ 一定要寫 127.0.0.1 不要寫 localhost：
  這台機器的 /etc/hosts 讓 localhost 先解到 ::1，而 Janet 的 net/connect 只取
  getaddrinfo 的第一筆，對只聽 IPv4 的後端會直接 connection refused。"
  "http://127.0.0.1:4000")

(def default-proxy-key
  "litellm proxy 沒設 master key 時隨便一個字串都收，但 header 不能不送。"
  "dummy")

(def chat-path
  "OpenAI 相容伺服器的 chat completions 路徑。"
  "/v1/chat/completions")

(defn base-url
  "proxy 的 base URL。環境變數 LITELLM_BASE 可覆寫（換 port 起第二台時很好用）。"
  []
  (or (os/getenv "LITELLM_BASE") default-base))

(defn chat-url
  ``組出 /v1/chat/completions 的完整網址。

  base 省略時用 base-url。結尾多打的 `/` 會被吃掉，所以
  "http://127.0.0.1:4000/" 與 "http://127.0.0.1:4000" 結果一樣。``
  [&opt base]
  (def b (string (or base (base-url))))
  (def trimmed
    (if (string/has-suffix? "/" b) (string/slice b 0 -2) b))
  (string trimmed chat-path))

(defn proxy-key
  "送給 proxy 的 Bearer token。環境變數 LITELLM_API_KEY 可覆寫。"
  []
  (or (os/getenv "LITELLM_API_KEY") default-proxy-key))
