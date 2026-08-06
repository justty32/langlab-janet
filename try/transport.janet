(import spork/http)
(import spork/json)

(defn post-chat
  ``post chat``
  [cfg payload]
  (def url (or
            (cfg :url) "http://127.0.0.1:4000/v1/chat/completions"))
  (def headers {"content-type" "application/json"
               "authorization" (string "Bearer "
                                       (or (cfg :api-key) "dummy"))})
  (def [ok res]
    (protect
      (http/request "POST" url
                    :body (json/encode payload)
                    :headers headers)))
  (unless ok (error "post failed"))
  (def text
    (string (or (res :body) "")))
  (unless
    (<= 200 (res :status) 299)
    (error "not 200"))
  (def [ok2 data]
    (protect (json/decode text true)))
  (unless ok2
    (error "text bad"))
  data)