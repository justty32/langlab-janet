# llm-http 的 endpoint 設定檔**範本**。
#
# ⚠ 這個檔案是**資料不是程式**：內容只會被 parse（`parse-all`），**不會被 eval**。
#   所以不要寫 (def …)／(import …)／(os/getenv …)，寫了也只是一串沒人執行的 tuple。
#   要從環境變數讀金鑰請用 :api-key-env（見下面 openai-direct 那筆）。
#
# ── 放哪裡 ──────────────────────────────────────────────────────────
#   複製一份到下列任一位置，模組 import 時會自動載入（找不到就靜靜跳過）：
#
#     ① $LLM_HTTP_ENDPOINTS 指的檔案             ← 優先序最高
#     ② $XDG_CONFIG_HOME/llm-http/endpoints.janet
#     ③ ~/.config/llm-http/endpoints.janet
#
#   也可以明確指定，不靠自動探測：
#     程式裡： (llm/load-endpoints! "/路徑/endpoints.janet")
#     CLI：    ./build/llm-http --endpoints /路徑/endpoints.janet 我的名字 "嗨"
#
#   → 這樣就**不必改 repo 裡的原始碼**，也不會把自己的設定 commit 進來。
#
# ── 格式 ────────────────────────────────────────────────────────────
#   最外層一張表：`"endpoint 名字" {設定}`。檔案裡可以有多張表，會依序疊加。
#   （副檔名改成 .json 的話就寫成 JSON，欄位名一樣。）
#
#   一份設定認得的欄位（只有 :model 必填，其餘都可省略）：
#
#     :model       送給 proxy／伺服器的 model 名稱                 ← **必填**
#     :base        proxy base URL；沒給就用 http://127.0.0.1:4000
#     :url         完整的 chat completions 網址；給了就完全不看 :base
#                  （拿來繞過 proxy 直接打 LM Studio 之類的伺服器）
#     :api-key     Bearer token（⚠ 別把真金鑰 commit 進版控，優先用 :api-key-env）
#     :api-key-env 從這個環境變數讀 token
#     :headers     額外的 request header，{"名字" "值"}，同名蓋掉預設的
#     :params      這條線的**預設請求參數**，{:temperature 0.2 :max_tokens 512 …}
#                  ⚠ key 用 payload 的原名（snake_case）：:max_tokens 不是 :max-tokens
#     :env         這條線在 **proxy 那端**需要的環境變數（只影響 --list 的提示）
#     :vision?     這條線指到的模型吃不吃圖；不確定就別給
#     :note        一句話說明，會出現在 --list
#
#   欄位名打錯會在載入時被擋下來並告訴你可用欄位，不會靜靜被忽略。
#
#   請求參數的合併優先序（低 → 高）：
#     endpoint 的 :params  ＜  呼叫端的 :params／CLI 的 --param
#                          ＜  具名參數／--temperature 等  ＜  chat 的 :extra

{# ── ① 走 litellm proxy，只是換一個 model 名並帶預設參數 ──────────────
 # lite.yaml 裡要有對應的 model_name: qwen
 "qwen"
 {:model   "qwen"
  :params  {:temperature 0.2 :max_tokens 512}
  :vision? false
  :note    "本機 proxy 上的 Qwen；固定低溫、短回應。"}

 # ── ② 完全繞過 proxy，直接打 LM Studio ──────────────────────────────
 # LM Studio 自己就是 OpenAI 相容伺服器，給了 :url 就不需要 litellm 了。
 # ⚠ 一律寫 127.0.0.1 不要寫 localhost（::1 陷阱，見 FINDINGS.md 第五節）。
 # ⚠ spork/http 沒有 TLS，:url 只能是 http:// 不能是 https://。
 "lmstudio"
 {:model   "google/gemma-4-e4b"
  :url     "http://127.0.0.1:1234/v1/chat/completions"
  :api-key "lm-studio"
  :vision? true
  :note    "直接打 LM Studio，不經 litellm proxy。"}

 # ── ③ 另一台 proxy（換 port／換機器）────────────────────────────────
 "proxy-4111"
 {:model "local"
  :base  "http://127.0.0.1:4111"
  :note  "第二台 litellm proxy。"}

 # ── ④ 金鑰從環境變數讀，設定檔裡不落密 ──────────────────────────────
 # ⚠ 這筆是**示意**：spork/http 沒有 TLS，https:// 其實打不通，
 #   真的要打外部服務請讓 litellm proxy 代打（:base 指回本機 proxy）。
 "openai-direct"
 {:model       "gpt-4o-mini"
  :url         "http://127.0.0.1:4000/v1/chat/completions"
  :api-key-env "OPENAI_API_KEY"
  :headers     {"x-my-tag" "janet-lab"}
  :params      {:temperature 0.7 :top_p 0.9}
  :env         "OPENAI_API_KEY"
  :note        "金鑰讀自環境變數，設定檔裡不留密。"}}
