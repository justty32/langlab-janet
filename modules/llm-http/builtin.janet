# 內建 endpoint 的**純資料** —— 這一支沒有任何行為，只有一張表。
#
# ★ 架構前提：Janet 這端**只講 OpenAI 相容這一種格式**。
#   四家 provider（LM Studio／DeepSeek／Anthropic／OpenRouter）的 wire format 差異
#   全部由前面那台 litellm proxy 吸收，所以這裡的 :model 其實是 **proxy config 裡的
#   model_name**（見同目錄 lite.yaml），不是 provider 自己的 model id。
#   要換 provider 就換 proxy 的 config，Janet 這邊一行都不用改。
#   唯一的例外是 claude-direct：:api :anthropic 讓 provider-anthropic.janet 在本機做
#   OpenAI ↔ Anthropic 的雙向轉換，:transport :curl 讓 https 打得出去，不需要 proxy。
#
# 使用者自己的 endpoint **不要**寫進這裡 —— 走 registry.janet 的 define-endpoint
# 或 config.janet 的設定檔（見 endpoints.example.janet）。

(def builtin-specs
  ``五個一等公民 endpoint（四筆走 proxy ＋ claude-direct 直打）。key 是給人用的名字，值是這一筆的中繼資料。

  一份 endpoint 設定認得的欄位（全部可省略，只有 :model 必填）：

    :model       送給 proxy／伺服器的 model 名稱（**必填**）
    :base        proxy base URL；沒給就用 defaults/base-url
    :url         完整的 chat completions 網址；給了就完全不看 :base
                 （拿來繞過 proxy 直接打 LM Studio 之類的伺服器）
    :api-key     Bearer token；沒給就用 defaults/proxy-key
    :api-key-env 從這個環境變數讀 token（設定檔裡不落金鑰時用）
    :headers     額外的 request header，{"名字" "值"}，同名蓋掉預設的
    :params      這條線的預設請求參數，{:temperature 0.2 :max_tokens 512 …}
    :env         這條線在 **proxy 那端**需要的環境變數；nil 表示不需要
    :vision?     這條線目前指到的模型吃不吃圖像輸入；不知道就別給（見下）
    :note        一句話說明
    :api         :openai（預設）或 :anthropic（本機轉成 Messages API，見 provider-anthropic.janet）
    :transport   :http（預設，spork/http）或 :curl（子行程呼叫 curl，https 才打得通）
                 ⚠ :url 是 https:// 開頭時會**自動**走 curl，不用特別寫
    :anthropic-version  送給 Anthropic 的版本 header，預設 "2023-06-01"
    :timeout     單次請求的秒數上限（目前只有 curl 那條會用）

  ⚠ :vision? 沒給時是 nil＝「不表態」，CLI 只有在它**明確是 false** 時才警告送圖。``
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

   "claude-direct"
   {:model       "claude-sonnet-5"
    :api         :anthropic
    :transport   :curl
    :api-key-env "ANTHROPIC_API_KEY"
    :env         nil
    :vision?     true
    :note        "直打 Anthropic Messages API（不經 proxy，curl 走 https）。⚠ 本機沒設 key，這條尚未實測。"}

   "openrouter"
   {:model   "openrouter"
    :env     "OPENROUTER_API_KEY"
    :vision? false
    :note    "OpenRouter，一個端點通吃多家（含 Claude）。⚠ 本機沒設 key，這條尚未實測；吃不吃圖看你在 proxy 選的 slug。"}})
