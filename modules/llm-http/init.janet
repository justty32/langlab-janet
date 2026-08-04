# llm-http —— 純 Janet 的 OpenAI 相容客戶端（門面）。
#
#   純 Janet（spork/http + spork/json）
#       └── http://127.0.0.1:4000   ← litellm proxy（本機、純 http、不需 TLS）
#             └── Anthropic / DeepSeek / LM Studio / OpenRouter
#
# proxy 擋在前面，所以 Janet 這端**只需要講 OpenAI 相容這一種格式**，各家 provider 的
# wire format 差異全由 litellm 吸收。**也可以完全不走 proxy**：給 endpoint 一個完整的
# :url，就直接打 LM Studio 之類的 OpenAI 相容伺服器。起 proxy 的指令與坑見 README.md。
#
# ── 這支檔案只做 re-export ──────────────────────────────────────────
#   endpoints.janet  ← 門面，底下再分四支：
#       defaults.janet   預設位址／金鑰、chat-url 怎麼組
#       builtin.janet    內建四筆 endpoint 的純資料
#       registry.janet   registry 行為：define-endpoint／endpoint／驗證
#       config.janet     設定檔載入：load-endpoints!／autoload-endpoints!
#   client.janet     ← 門面，底下再分兩支：
#       transport.janet  HTTP／JSON 收送
#       chat.janet       對話語意：chat／ask／取答案／參數合併
#   media.janet      圖像輸入：圖檔 → base64 data URI → content parts
#   tools.janet      多輪 tool loop
#   cli.janet        CLI 的參數解析／輸出格式（main.janet 只是薄薄的進入點）
#
# 用法：(import ../modules/llm-http/init :as llm) 就一次拿到全部公開函式。
# 想只拿某一層也可以直接 import 個別檔案，例如 (import ../modules/llm-http/tools)。
#
# ★ import 這支的**副作用**：會自動探測一次使用者的 endpoint 設定檔
#   （LLM_HTTP_ENDPOINTS → $XDG_CONFIG_HOME/llm-http/endpoints.janet
#     → ~/.config/llm-http/endpoints.janet）。沒有設定檔是正常狀態，不會有任何輸出。

(import ./endpoints :prefix "" :export true)
(import ./client    :prefix "" :export true)
(import ./media     :prefix "" :export true)
(import ./tools     :prefix "" :export true)
