#!/usr/bin/env janet
# 開一台 local HTTP server，然後用 API 去問它（GET / POST / JSON / 404 / 連不上）。
# 跑法：
#   janet snippets/http-local/main.janet                       # 起 server 再自己問自己
#   janet snippets/http-local/main.janet serve 8080            # 只當 server，一直跑
#   janet snippets/http-local/main.janet get http://example.com/  # 只當 client，問外面
#
# server 與 client 都在 spork/http；底層是內建的 net + ev，天生併發。
# 兩半各自的重點寫在 server.janet／client.janet 的檔頭。

(import spork/json)
(import ./server :as srv)
(import ./client :as cl)

(defn h [s] (printf "\n── %s" s))

(defn- demo-self
  "預設模式：起 server 再自己問自己，把各種情況跑一遍。"
  []
  (h "起 local server")
  (def s (srv/start-server "127.0.0.1" 8954))
  (ev/sleep 0.1)                                  # 給它一點時間 listen
  (def base "http://127.0.0.1:8954")

  (h "GET 純文字")
  (cl/show "GET /" (cl/fetch "GET" (string base "/")))

  (h "GET JSON 並解成 table")
  (def r (cl/fetch-json "GET" (string base "/api/users")))
  (cl/show "GET /api/users" r)
  (printf "      解出來：count=%q 第一位=%q"
          (get-in r [:json :count])
          (get-in r [:json :users 0 :name]))

  (h "動態路徑")
  (cl/show "GET /api/users/2"  (cl/fetch "GET" (string base "/api/users/2")))
  (cl/show "GET /api/users/99" (cl/fetch "GET" (string base "/api/users/99")))

  (h "POST 送 JSON")
  (cl/show "POST /api/echo?a=1"
           (cl/fetch "POST" (string base "/api/echo?a=1")
                     :body (json/encode {:x 1 :y "值"})
                     :headers {"content-type" "application/json"}))

  (h "錯誤處理")
  (cl/show "GET /nope"    (cl/fetch "GET" (string base "/nope")))
  (cl/show "連不上的 port" (cl/fetch "GET" "http://127.0.0.1:9/"))

  (h "並行問十次（ev 的好處）")
  (def t0 (os/clock))
  # ev/gather 是巨集、吃的是「運算式」不是陣列，所以這裡用十個 fiber + channel
  (def ch (ev/chan 10))
  (for i 0 10
    (ev/spawn (ev/give ch (cl/fetch "GET" (string base "/api/users")))))
  (def rs (seq [_ :range [0 10]] (ev/take ch)))
  (printf "  10 個請求全成功？%q，花了 %.3f 秒"
          (all |($ :ok) rs) (- (os/clock) t0))

  (:close s)
  (print))

(defn main [& args]
  (case (get args 1)
    # 只當 server，一直跑
    "serve"
    (do
      (def port (if-let [p (get args 2)] (scan-number p) 8080))
      (srv/start-server "127.0.0.1" port)
      (print "  Ctrl-C 結束")
      (forever (ev/sleep 60)))

    # 只當 client，問外面的位址
    "get"
    (let [url (or (get args 2) "http://example.com/")]
      (h (string "GET " url))
      (cl/show "外部" (cl/fetch "GET" url)))

    (demo-self)))
