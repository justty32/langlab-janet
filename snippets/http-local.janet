#!/usr/bin/env janet
# 開一台 local HTTP server，然後用 API 去問它（GET / POST / JSON / 404 / 連不上）。
# 跑法：
#   janet snippets/http-local.janet                       # 起 server 再自己問自己
#   janet snippets/http-local.janet serve 8080            # 只當 server，一直跑
#   janet snippets/http-local.janet get http://example.com/  # 只當 client，問外面
#
# 重點：
#   * server 與 client 都在 spork/http；底層是內建的 net + ev，天生併發
#   * ★ handler 拿到的 req 一開始「沒有」body，要自己 (http/read-body req) 才會有
#   * (req :path) 含 query string；(req :route) 是去掉問號那段的純路徑，路由用它
#   * ★ URL 路徑裡的非 ASCII 字元要自己 percent-encode，否則 server 端解出來是殘的
#   * client 連不上會丟例外（不是回 nil），用 protect / try 接
#   * 回應的 :body 是 buffer，要字串包一層 (string …)

(import spork/http)
(import spork/json)

(defn h [s] (printf "\n── %s" s))

# ── server 這一半 ────────────────────────────────────────────────────
(def 假資料
  @{"1" @{:id 1 :name "Alice" :role "admin"}
    "2" @{:id 2 :name "Bob"   :role "user"}})

(defn json-response [status data]
  {:status status
   :headers {"content-type" "application/json; charset=utf-8"}
   :body (json/encode data)})

(def routes
  {"/" (fn [req]
         {:status 200
          :headers {"content-type" "text/plain; charset=utf-8"}
          :body "janet-lab demo server\n試試 /api/users/1 或 POST /api/echo\n"})

   "/api/users" (fn [req]
                  (json-response 200 {:users (values 假資料) :count (length 假資料)}))

   "/api/echo" (fn [req]
                 # ★ 這一行不寫，(req :body) 會是 nil
                 (http/read-body req)
                 (json-response 200
                                {:method (req :method)
                                 :path   (req :path)
                                 :query  (req :query-string)
                                 :body   (string (or (req :body) ""))}))})

(defn make-router
  "spork/http 的 router 是「路徑 → handler」的表。動態路徑（/api/users/:id）
  它不幫你解，自己包一層 fallback 處理。"
  []
  (def base (http/router routes))
  (fn [req]
    (def path (or (req :route) (first (string/split "?" (req :path)))))
    (if-let [[id] (peg/match ~(* "/api/users/" (<- (some (range "09"))) -1) path)]
      (if-let [u (get 假資料 id)]
        (json-response 200 u)
        (json-response 404 {:error "沒有這個 user" :id id}))
      (base req))))

(defn start-server [host port]
  (def s (http/server (make-router) host port))
  (printf "  server 起來了：http://%s:%d" host port)
  s)

# ── client 這一半 ────────────────────────────────────────────────────
(defn fetch
  "問一個 URL，回傳 @{:ok :status :headers :body}。連不上不會丟例外。"
  [method url &named body headers]
  (def [ok res]
    (protect (http/request method url
                           :body body
                           :headers (or headers {}))))
  (if ok
    @{:ok true
      :status  (res :status)
      :headers (res :headers)
      :body    (string (res :body))}       # ★ 原本是 buffer
    @{:ok false :error (string res)}))

(defn fetch-json
  "同上，但把回應的 body 當 JSON 解成 table（key 是 keyword）。"
  [method url &named body headers]
  (def r (fetch method url :body body :headers headers))
  (when (r :ok)
    # ★ protect 回的是 (成功? 值)，要取第二個；寫成 (first …) 會拿到 true
    (def [ok v] (protect (json/decode (r :body) true)))
    (put r :json (if ok v nil)))
  r)

(defn show [label r]
  (if (r :ok)
    (do
      (printf "  %s → %d" label (r :status))
      (printf "      content-type: %s" (or (get-in r [:headers "content-type"]) "（無）"))
      (printf "      body: %s" (string/trimr (r :body))))
    (printf "  %s → ✗ %s" label (r :error))))

# ── 三種跑法 ─────────────────────────────────────────────────────────
(defn main [& args]
  (def mode (get args 1))

  (case mode
    # 只當 server，一直跑
    "serve"
    (do
      (def port (if-let [p (get args 2)] (scan-number p) 8080))
      (start-server "127.0.0.1" port)
      (print "  Ctrl-C 結束")
      (forever (ev/sleep 60)))

    # 只當 client，問外面的位址
    "get"
    (do
      (def url (or (get args 2) "http://example.com/"))
      (h (string "GET " url))
      (show "外部" (fetch "GET" url)))

    # 預設：起 server 再自己問自己
    (do
      (h "起 local server")
      (def s (start-server "127.0.0.1" 8954))
      (ev/sleep 0.1)                                  # 給它一點時間 listen
      (def base "http://127.0.0.1:8954")

      (h "GET 純文字")
      (show "GET /" (fetch "GET" (string base "/")))

      (h "GET JSON 並解成 table")
      (def r (fetch-json "GET" (string base "/api/users")))
      (show "GET /api/users" r)
      (printf "      解出來：count=%q 第一位=%q"
              (get-in r [:json :count])
              (get-in r [:json :users 0 :name]))

      (h "動態路徑")
      (show "GET /api/users/2"     (fetch "GET" (string base "/api/users/2")))
      (show "GET /api/users/99"    (fetch "GET" (string base "/api/users/99")))

      (h "POST 送 JSON")
      (show "POST /api/echo?a=1"
            (fetch "POST" (string base "/api/echo?a=1")
                   :body (json/encode {:x 1 :y "值"})
                   :headers {"content-type" "application/json"}))

      (h "錯誤處理")
      (show "GET /nope"    (fetch "GET" (string base "/nope")))
      (show "連不上的 port" (fetch "GET" "http://127.0.0.1:9/"))

      (h "並行問十次（ev 的好處）")
      (def t0 (os/clock))
      # ev/gather 是巨集、吃的是「運算式」不是陣列，所以這裡用十個 fiber + channel
      (def ch (ev/chan 10))
      (for i 0 10
        (ev/spawn (ev/give ch (fetch "GET" (string base "/api/users")))))
      (def rs (seq [_ :range [0 10]] (ev/take ch)))
      (printf "  10 個請求全成功？%q，花了 %.3f 秒"
              (all |($ :ok) rs) (- (os/clock) t0))

      (:close s)
      (print))))
