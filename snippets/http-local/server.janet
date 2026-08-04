# HTTP server 這一半 —— spork/http 的 router、handler、動態路徑。
#
# 重點：
#   * ★ handler 拿到的 req 一開始「沒有」body，要自己 (http/read-body req) 才會有
#   * (req :path) 含 query string；(req :route) 是去掉問號那段的純路徑，路由用它
#   * router 只認**固定路徑**，動態路徑（/api/users/:id）要自己包一層 fallback

(import spork/http)
(import spork/json)

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
