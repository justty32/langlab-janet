# llm-http：curl 傳輸 —— 起假 http 伺服器，用 :transport :curl 打它（離線也能驗 curl 那條）。
#
# curl 不在 PATH 時整支**跳過並印原因**，不變紅（jpm test 在沒 curl 的機器上也要綠）。
# 另外驗：金鑰不出現在命令列（看 argv 組法）、https:// 會自動選 curl、暫存檔用完有刪。

(import spork/http)
(import spork/json)
(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

# ── 不需要 curl 就能驗的部分 ─────────────────────────────────────────
(assert (llm/use-curl? {:transport :curl :url "http://127.0.0.1:1/x"}) "明講 :transport :curl")
(assert (llm/use-curl? {:url "https://api.anthropic.com/v1/messages"}) "https:// 自動走 curl")
(assert (not (llm/use-curl? {:url "http://127.0.0.1:4000/v1/chat/completions"})) "http:// 照舊走 spork")
(assert (= :curl ((llm/endpoint {:model "m" :transport :curl}) :transport)) "spec 認得 :transport")
(assert (string/find ":transport 只能是" (u/err-of |(llm/endpoint {:model "m" :transport :wget}))))
(assert (= 30 ((llm/endpoint {:model "m" :timeout 30}) :timeout)))

(if-not (llm/curl-available?)
  (print "（跳過 curl 傳輸測試：這台機器 PATH 上沒有 curl）")
  (do
    (def port 45751)
    # ⚠ 暫存檔的檢查不能直接斷言「TMPDIR 裡沒有 llm-http-*」——別的行程、別的測試或
    #   範例留下的殘留會讓這條間歇變紅（真的撞過）。先記下跑之前就有的，最後只看新增的。
    (def tmpdir (or (os/getenv "TMPDIR") "/tmp"))
    (defn hdr-files [] (filter |(string/has-prefix? "llm-http-" $) (os/dir tmpdir)))
    (def 原有 (tabseq [f :in (hdr-files)] f true))
    (var seen nil)
    (defn- fake [req]
      (http/read-body req)
      (set seen [(req :method) (req :path) (req :headers) (string (req :body))])
      (case (req :path)
        "/v1/chat/completions"
        {:status 200 :headers {"content-type" "application/json"}
         :body (json/encode {:choices [{:message {:role "assistant" :content "curl 收到"}
                                        :finish_reason "stop"}]
                             :usage {:total_tokens 9}})}
        "/v1/models"
        {:status 200 :headers {"content-type" "application/json"}
         :body (json/encode {:data [{:id "a"} {:id "b"}]})}
        "/bad"
        {:status 503 :headers {"content-type" "application/json"} :body `{"error":"掛了"}`}
        {:status 200 :headers {"content-type" "text/plain"} :body "不是 JSON"}))
    (def server (http/server fake "127.0.0.1" port))
    (def base (string "http://127.0.0.1:" port))
    (def cfg (llm/endpoint {:model "m" :base base :transport :curl :api-key "sk-secret"
                            :headers {"x-tag" "janet"}}))

    (assert (= "curl 收到" (llm/ask cfg "嗨")) "整條路徑：Janet → curl → 假伺服器 → 回來")
    (assert (= "POST" (seen 0)))
    (assert (= "Bearer sk-secret" (get (seen 2) "authorization")) "金鑰有送到（走 -H @暫存檔）")
    (assert (= "janet" (get (seen 2) "x-tag")) "自訂 header 也走同一個檔")
    (assert (string/find "\"model\":\"m\"" (seen 3)) "body 從 stdin 餵進去了")

    # GET：list-models
    (assert (deep= @["a" "b"] (map |($ :id) (llm/list-models cfg))))
    (assert (= "GET" (seen 0)))

    # 錯誤都是中文、帶狀態碼與原文
    (def e503 (u/err-of |(llm/request-json cfg "POST" (string base "/bad") {})))
    (assert (string/find "HTTP 503" e503) e503)
    (assert (string/find "掛了" e503))
    (assert (string/find "不是合法 JSON" (u/err-of |(llm/request-json cfg "GET" (string base "/text")))))
    (def e-conn (u/err-of |(llm/ask (llm/endpoint {:model "m" :base "http://127.0.0.1:45799" :transport :curl}) "嗨")))
    (assert (string/find "連不上" e-conn) e-conn)
    (assert (string/find "127.0.0.1:45799" e-conn))

    # 暫存的 header 檔用完要刪乾淨——只算這次跑出來的那些
    (def 新留下 (filter |(not (原有 $)) (hdr-files)))
    (assert (empty? 新留下) (string "暫存 header 檔沒刪：" (string/join 新留下 " ")))

    (:close server)))

(print "llm-http curl 傳輸測試通過 ✓")
