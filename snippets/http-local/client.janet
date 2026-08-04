# HTTP client 這一半 —— 問一個 URL、把 JSON 解出來、把結果印得好看。
#
# 重點：
#   * client 連不上會**丟例外**（不是回 nil），用 protect / try 接
#   * 回應的 :body 是 **buffer**，要字串包一層 (string …)
#   * ⚠ spork/http 底層是 net/connect，**沒有 TLS**，https:// 打不通
#   * ⚠ URL 路徑裡的非 ASCII 要自己 percent-encode，否則 server 端解出來是殘的

(import spork/http)
(import spork/json)

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
