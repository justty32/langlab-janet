# HTTP 這一整塊的**門面** —— 相容入口。
#
# 原本這支檔案同時管 HTTP 傳輸與 chat／ask 的語意，現在拆成兩支：
#
#   transport.janet  HTTP／JSON 收送（post-chat／headers-for），不認識 messages
#   chat.janet       對話語意（build-payload／chat／ask／reply-text／reply-message）
#
# 舊寫法 (import ./client) 之後照舊：client/post-chat、client/chat、client/ask、
# client/reply-text、client/reply-message 全部還在。

(import ./transport :prefix "" :export true)
(import ./chat      :prefix "" :export true)
