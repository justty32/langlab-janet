# 串流用的 http 傳輸 —— net/connect ＋ 手寫最小 HTTP/1.1，一邊收一邊逐行交出去。
#
# 為什麼不用 spork/http 的 http/request：實測看它的 read-body——
#   content-type 是 text/event-stream 時它只 read-until "\n\n"，也就是**只讀第一個事件**就回，
#   而且 request 在 defer 裡把連線關掉了，後面的事件全丟。所以借它的 url-grammar 與
#   read-response（解狀態列與 header），body 自己讀：chunked 就逐塊解、有 content-length 就讀滿、
#   都沒有就讀到 EOF。每收到一段 bytes 就交給 on-bytes（上層再切行、解 SSE）。
#
# ⚠ read-response 回來的 :buffer 只剩 header 之後的殘餘 bytes（header 本身已消化掉），
#   chunked 的第一個 size 行常常已經在裡面了，所以「先看 buf 再向 conn 要」的順序不能反。
# ⚠ 這條只給 http://；https:// 由 transport/use-curl? 導去 stream-curl.janet。

(import spork/http)

(defn- fill!
  "從 conn 再讀一些進 buf；EOF 回 false。"
  [conn buf]
  (truthy? (:read conn 4096 buf)))

(defn- drop-front!
  "把 buf 前面 n 個 bytes 丟掉（⚠ 不用 buffer/blit 對自己搬：重疊區域的行為沒保證）。"
  [buf n]
  (def rest (string/slice buf n))
  (buffer/clear buf)
  (buffer/push buf rest))

(defn- take-line!
  "從 buf 前面切出一行（不含 \\r\\n）；需要時向 conn 要更多。"
  [conn buf]
  (var pos (string/find "\r\n" buf))
  (while (nil? pos)
    (unless (fill! conn buf) (error "串流中途斷線（讀 chunk 大小時遇到 EOF）"))
    (set pos (string/find "\r\n" buf)))
  (def line (string/slice buf 0 pos))
  (drop-front! buf (+ pos 2))
  line)

(defn- take-bytes!
  "從 buf 前面切出 n 個 bytes 交給 on-bytes（分次交也行）；需要時向 conn 要更多。"
  [conn buf n on-bytes]
  (var left n)
  (while (pos? left)
    (when (empty? buf)
      (unless (fill! conn buf) (error "串流中途斷線（body 沒讀完就 EOF）")))
    (def k (min left (length buf)))
    (on-bytes (string/slice buf 0 k))
    (drop-front! buf k)
    (-= left k)))

(defn- read-chunked!
  [conn buf on-bytes]
  (while true
    (def size (scan-number (string/trim (take-line! conn buf)) 16))
    (when (or (nil? size) (zero? size)) (break))
    (take-bytes! conn buf size on-bytes)
    (take-line! conn buf)))                     # chunk 後面那個 CRLF

(defn- read-until-eof!
  [conn buf on-bytes]
  (unless (empty? buf) (on-bytes (string buf)) (buffer/clear buf))
  (while (fill! conn buf)
    (on-bytes (string buf))
    (buffer/clear buf)))

(defn stream-post
  ``POST 一份 body 到 url（http://），把回應 body 一段段交給 on-bytes。
  非 2xx 把整份 body 讀完後丟中文錯誤；連不上也是中文錯誤。``
  [url headers body on-bytes]
  (def x (peg/match http/url-grammar url))
  (unless x (error (string "網址格式不對：" url)))
  (def [scheme host raw-port path] x)
  (when (= scheme "https") (error "stream-http 只走 http://，https 請走 curl"))
  (def port (or raw-port "80"))
  (def [ok conn] (protect (net/connect host port)))
  (unless ok
    (error (string "連不上 " url "：" conn
                   "\n（後端起來了嗎？位址一定要用 127.0.0.1 不要用 localhost）")))
  (defer (:close conn)
    (def buf @"")
    (buffer/format buf "POST %s HTTP/1.1\r\nHost: %s:%s\r\n" path host port)
    (eachp [k v] headers (buffer/format buf "%s: %s\r\n" k v))
    (buffer/format buf "Content-Length: %d\r\n\r\n%V" (length body) body)
    (:write conn buf)
    (buffer/clear buf)
    (def res (http/read-response conn buf))
    (when (= :error res) (error (string "回應的 HTTP header 解不開：" url)))
    (def status (res :status))
    (def hs (res :headers))
    (unless (and status (<= 200 status 299))
      (http/read-body res)
      (error (string/format "HTTP %q（%s）：%s" status url (string/trim (string (res :body))))))
    (cond
      (= "chunked" (get hs "transfer-encoding")) (read-chunked! conn buf on-bytes)
      (get hs "content-length") (take-bytes! conn buf (scan-number (get hs "content-length")) on-bytes)
      (read-until-eof! conn buf on-bytes))))
