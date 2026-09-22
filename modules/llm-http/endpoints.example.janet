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
#   ⚠ 自動探測（①②③）是 **import 時**做的，所以 jpm build 編出來的 build/llm-http 會把
#     探測結果凍在 build 當下：改了這個檔之後，當次生效請用 --endpoints，永久生效要
#     `jpm clean && jpm build`。走 import／直接跑原始碼都沒這問題（見 FINDINGS-踩坑b 二十五）。
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
 # https:// 的 :url 會自動改走 curl 子行程（spork/http 本身沒有 TLS），所以直打外部服務
 # 是通的；沒裝 curl 的機器才要讓 litellm proxy 代打（:base 指回本機 proxy）。
 "openai-direct"
 {:model       "gpt-4o-mini"
  :url         "https://api.openai.com/v1/chat/completions"
  :api-key-env "OPENAI_API_KEY"
  :headers     {"x-my-tag" "janet-lab"}
  :params      {:temperature 0.7 :top_p 0.9}
  :env         "OPENAI_API_KEY"
  :note        "金鑰讀自環境變數，設定檔裡不留密。"}

 # ── ⑤ 對上「不是 lite.yaml」的外部 litellm ──────────────────────────
 # 內建那幾筆的 :model（local／deepseek／claude／openrouter）是照本 repo 的 lite.yaml 取的；
 # 換成別人家的 proxy 時那些名字通常一個都不在，內建 endpoint 會全部打不通。
 # :model 要抄**那台 proxy 自己的 model_name**（`curl <base>/v1/models` 看得到）。
 # 有些 proxy 會把「同一顆模型 × 不同思考深度」拆成好幾個 model_name，這時思考深度是靠
 # 選名字決定的，不要自己送 reasoning_effort（很可能被 proxy 的 drop_params 吞掉）。
 "op5"
 {:model   "claude-opus-5"
  :vision? true
  :note    "外部 proxy 上的一筆 model_name；名字要跟那台對得起來。"}

 "op5-nothink"
 {:model   "claude-opus-5-nothink"
  :vision? true
  :note    "同一顆模型的另一個 model_name＝關掉思考的分身。"}}
