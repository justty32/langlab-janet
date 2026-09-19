# HTTP 這一整塊的**門面** —— 相容入口。
#
# 原本這支檔案同時管 HTTP 傳輸與 chat／ask 的語意，現在拆成兩支：
#
#   transport.janet        HTTP／JSON 收送（post-chat／request-json／headers-for），不認識 messages
#   transport-curl.janet   curl 子行程那條傳輸（https 用）
#   provider-anthropic.janet  :api :anthropic 的雙向轉換（＋ anthropic-req／anthropic-res）
#   retry.janet            只對連不上／5xx／429 的指數退避重試
#   chat.janet             對話語意（build-payload／chat／ask／reply-text／reply-message）
#   structured.janet       ask-json：結構化輸出（response_format）＋ 解 JSON
#   models.janet           list-models：GET /v1/models
#   sse.janet              SSE 逐行解析＋OpenAI 串流片段合併（純函式）
#   stream-anthropic.janet Anthropic 串流事件合併（純函式）
#   stream.janet           chat-stream／ask-stream：SSE 串流（傳輸在 stream-http／stream-curl）
#
# 舊寫法 (import ./client) 之後照舊：client/post-chat、client/chat、client/ask、
# client/reply-text、client/reply-message 全部還在。

(import ./transport-curl     :prefix "" :export true)
(import ./transport          :prefix "" :export true)
(import ./provider-anthropic :prefix "" :export true)
(import ./retry              :prefix "" :export true)
(import ./chat               :prefix "" :export true)
(import ./structured         :prefix "" :export true)
(import ./models             :prefix "" :export true)
(import ./sse                :prefix "" :export true)
(import ./stream-anthropic   :prefix "" :export true)
(import ./stream             :prefix "" :export true)
