# 串流用的 curl 傳輸 —— `curl -N` 逐段讀 stdout，交給上層切行解 SSE。
#
# https:// 沒有別條路（spork 沒 TLS），所以串流打 Anthropic／OpenAI 一定走這裡。
# -N（--no-buffer）讓 curl 收到多少就吐多少，不然它會攢到 4 KB 才寫 stdout，串流就沒意義了。
#
# ★ 狀態碼還是靠 -w '\n%{http_code}' 接在最後：非 2xx 時 body 是一份 JSON 錯誤（不是 SSE），
#   那些行不會以 data: 開頭、SSE 解析會略過，所以這裡把「非 data 行」全部留下來，
#   最後一行當狀態碼、其餘當錯誤內文。
# ★ curl 自己失敗（exit ≠ 0）優先於 HTTP 狀態：連不上時根本沒有狀態碼。

(import ./transport-curl :as curl)
(import ./sse)

(defn stream-post
  ``POST body 到 url，把 stdout 一段段交給 on-bytes（跟 stream-http/stream-post 同形狀）。
  timeout 是秒數或 nil。``
  [url headers body on-bytes &opt timeout]
  (def others @[])                             # 非 data: 的行（錯誤內文＋最後的狀態碼）
  (def split (sse/make-line-splitter
               (fn [line]
                 (unless (string/has-prefix? "data:" line)
                   (unless (empty? line) (array/push others line))))))
  (def [_ code err]
    (curl/curl-run "POST" url headers body timeout ["-N"]
      (fn [p]
        (def buf @"")
        (while (ev/read (p :out) 4096 buf)
          (on-bytes (string buf))
          (split (string buf))
          (buffer/clear buf))
        (split nil))))
  (unless (zero? code)
    (error (string "連不上 " url "：curl 失敗（exit " code "）：" (string/trim err))))
  (def status (scan-number (or (last others) "")))
  (unless (and status (<= 200 status 299))
    (error (string/format "HTTP %q（%s）：%s" status url
                          (string/join (array/slice others 0 -2) "\n")))))
