# llm-http —— 純 Janet 的 litellm proxy 客戶端（門面）。
#
#   純 Janet（spork/http + spork/json）
#       └── http://127.0.0.1:4000   ← litellm proxy（本機、純 http、不需 TLS）
#             └── Anthropic / DeepSeek / LM Studio / OpenRouter
#
# proxy 擋在前面，所以 Janet 這端**只需要講 OpenAI 相容這一種格式**，四家 provider 的
# wire format 差異全由 litellm 吸收。起 proxy 的指令與坑見同目錄的 README.md。
#
# ── 這支檔案只做 re-export ──────────────────────────────────────────
# 真正的東西分在四個檔案裡：
#   endpoints.janet  endpoint／model 設定表（local／deepseek／claude／openrouter）
#   client.janet     HTTP／JSON 收送、取答案
#   media.janet      圖像輸入：圖檔 → base64 data URI → content parts
#   tools.janet      多輪 tool loop
#
# 用法：(import ../modules/llm-http/init :as llm) 就一次拿到全部公開函式。
# 想只拿某一層也可以直接 import 個別檔案，例如 (import ../modules/llm-http/tools)。

(import ./endpoints :prefix "" :export true)
(import ./client    :prefix "" :export true)
(import ./media     :prefix "" :export true)
(import ./tools     :prefix "" :export true)
