# Anthropic 原生 Messages API 這條線的**門面** —— header、網址、送出去再轉回來。
#
# cfg 給 :api :anthropic 時走這裡。雙向轉換都是純函式，拆在兩支：
#   anthropic-req.janet   OpenAI payload → Anthropic request（to-anthropic）
#   anthropic-res.janet   Anthropic 回應 → OpenAI 形狀（from-anthropic）
# 本檔只把它們接上傳輸層：組 header（x-api-key 不是 Bearer）、決定網址、送、轉回。
#
# 模型 id 與參數是照 claude-api skill（2026-06 快取）查的：現行 Sonnet 是 claude-sonnet-5，
# 版本 header 仍是 anthropic-version: 2023-06-01。
# ⚠ 本機沒有 ANTHROPIC_API_KEY，真打 API 那段**未實測**；離線驗的是雙向轉換與假伺服器的 tool loop。
# ⚠ 金鑰沒設時 resolve 會填預設的 "dummy"，這裡先擋下來講清楚，不要等 Anthropic 回 401。

(import ./defaults :as d)
(import ./transport :as tp)
(import ./anthropic-req :prefix "" :export true)
(import ./anthropic-res :prefix "" :export true)

(defn anthropic?
  "這份 cfg 是不是走 Anthropic 原生 API。"
  [cfg]
  (= :anthropic (keyword (or (get cfg :api) :openai))))

(defn anthropic-headers
  ``組 Anthropic 要的 header：content-type、x-api-key、anthropic-version。
  cfg 的 :headers 疊在上面（放 anthropic-beta 就從這裡進來），同名以使用者的為準。``
  [cfg]
  (def key (cfg :api-key))
  (when (or (nil? key) (= key d/default-proxy-key))
    (error (string "這條 Anthropic 線沒有金鑰：請設環境變數 "
                   (or (cfg :api-key-env) "ANTHROPIC_API_KEY")
                   "，或在 endpoint 給 :api-key")))
  (def h @{"content-type"      "application/json"
           "x-api-key"         key
           "anthropic-version" (or (cfg :anthropic-version) d/anthropic-version)})
  (when-let [extra (cfg :headers)]
    (eachp [k v] extra
      (put h (string/ascii-lower (string k)) (string v))))
  h)

(defn anthropic-url
  "要打的網址：cfg 的 :url，沒給就是 defaults/anthropic-url。"
  [cfg]
  (or (cfg :url) d/anthropic-url))

(defn post-anthropic
  ``把 OpenAI 形狀的 payload 轉成 Anthropic request 送出去，再把回應轉回 OpenAI 形狀。
  跟 transport/post-chat 同形狀，所以 chat／ask／with-tools 都不用知道底下是誰。``
  [cfg payload]
  (def req (to-anthropic payload))
  (def res (tp/request-json cfg "POST" (anthropic-url cfg) req (anthropic-headers cfg)))
  (from-anthropic res))
