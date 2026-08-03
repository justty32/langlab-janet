# endpoint／model 設定表 —— 這一層只管「要打哪個網址、用哪個 model 名、要不要帶 key」。
#
# ★ 架構前提：Janet 這端**只講 OpenAI 相容這一種格式**。
#   四家 provider（LM Studio／DeepSeek／Anthropic／OpenRouter）的 wire format 差異
#   全部由前面那台 litellm proxy 吸收，所以這裡的 :model 其實是 **proxy config 裡的
#   model_name**，不是 provider 自己的 model id。要換 provider 就換 proxy 的 config，
#   Janet 這邊一行都不用改。
#
# ★ proxy 在本機、走 http 不走 https → spork/http 直接打得到，不需要繞 curl。

(def default-base
  "litellm proxy 的預設位址。⚠ 一定要寫 127.0.0.1 不要寫 localhost：
  這台機器的 /etc/hosts 讓 localhost 先解到 ::1，而 Janet 的 net/connect 只取
  getaddrinfo 的第一筆，對只聽 IPv4 的後端會直接 connection refused。"
  "http://127.0.0.1:4000")

(def default-proxy-key
  "litellm proxy 沒設 master key 時隨便一個字串都收，但 header 不能不送。"
  "dummy")

(defn base-url
  "proxy 的 base URL。環境變數 LITELLM_BASE 可覆寫（換 port 起第二台時很好用）。"
  []
  (or (os/getenv "LITELLM_BASE") default-base))

(defn chat-url
  "組出 /v1/chat/completions 的完整網址。"
  [&opt base]
  (string (or base (base-url)) "/v1/chat/completions"))

(defn proxy-key
  "送給 proxy 的 Bearer token。環境變數 LITELLM_API_KEY 可覆寫。"
  []
  (or (os/getenv "LITELLM_API_KEY") default-proxy-key))

(def specs
  ``四個一等公民 endpoint。key 是給人用的名字，值是這一筆的中繼資料：

  :model   送給 proxy 的 model_name（要跟 lite.yaml 裡的 model_name 對得起來）
  :env     這條線在 **proxy 那端**需要的環境變數；nil 表示不需要
  :vision? 這條線目前指到的模型吃不吃圖像輸入
  :note    一句話說明``
  {"local"
   {:model   "local"
    :env     nil
    :vision? true
    :note    "本機 LM Studio（http://127.0.0.1:1234/v1），免金鑰；gemma-4 系列吃圖。"}

   "deepseek"
   {:model   "deepseek"
    :env     "DEEPSEEK_API_KEY"
    :vision? false
    :note    "DeepSeek 官方 API。⚠ 現行 model id 是 deepseek-v4-flash／deepseek-v4-pro，純文字、不吃圖。"}

   "claude"
   {:model   "claude"
    :env     "ANTHROPIC_API_KEY"
    :vision? true
    :note    "Anthropic Messages API，由 proxy 轉譯。⚠ 本機沒設 key，這條尚未實測。"}

   "openrouter"
   {:model   "openrouter"
    :env     "OPENROUTER_API_KEY"
    :vision? false
    :note    "OpenRouter，一個端點通吃多家（含 Claude）。⚠ 本機沒設 key，這條尚未實測；吃不吃圖看你在 proxy 選的 slug。"}})

(defn endpoint-names
  "內建 endpoint 的名字清單（排序過，方便印說明）。"
  []
  (sorted (keys specs)))

(defn endpoint
  ``依名字取一份**全新的** endpoint 設定 table；沒這個名字回 nil。

  回傳的 table 至少含 :name :model :url :api-key，可直接餵給 client/chat。
  overrides 會蓋在上面，最常用的是換 model 或換 base：
    (endpoint "local")
    (endpoint "local" {:model "qwen"})
    (endpoint "deepseek" {:base "http://127.0.0.1:4111"})

  ★ 每次都重新組一份，所以 overrides 不會污染下一次呼叫。``
  [name &opt overrides]
  (when-let [spec (get specs name)]
    (def base (get overrides :base))
    (def cfg @{:name    name
               :model   (spec :model)
               :url     (chat-url base)
               :api-key (proxy-key)
               :env     (spec :env)
               :vision? (spec :vision?)
               :note    (spec :note)})
    (when overrides
      (eachp [k v] overrides
        (unless (= k :base) (put cfg k v))))
    cfg))

(defn env-ready?
  "這條線在 proxy 端需要的環境變數有沒有設（不需要金鑰的回 true）。
  ⚠ 只是本機探測，proxy 可能跑在別的環境裡，僅供 --list 提示用。"
  [name]
  (def spec (get specs name))
  (def var-name (and spec (spec :env)))
  (if var-name (truthy? (os/getenv var-name)) true))
