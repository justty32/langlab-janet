# llm-http：**參數與 header 的合併優先序** —— 這一支是整個模組最容易踩錯的地方。
#
# 全部靠純函式驗（build-payload／headers-for），完全不打網路。
# 「真的送到 wire 上是不是這樣」由 llm-http-server.janet 拿假後端再驗一次。

(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

# ── 請求參數：低 → 高 ───────────────────────────────────────────────
#   endpoint 的 :params ＜ chat 的 :params ＜ 具名參數 ＜ :extra
(def pcfg (llm/endpoint {:model "m" :params {:temperature 0.2 :max_tokens 512 :top_p 0.9}}))

(def p1 (llm/build-payload pcfg @[]))
(assert (= 0.2 (p1 :temperature)) "沒人覆寫時用 endpoint 的 :params")
(assert (= 512 (p1 :max_tokens)))

(def p2 (llm/build-payload pcfg @[] :params {:temperature 0.5}))
(assert (= 0.5 (p2 :temperature)) ":params 蓋得掉 endpoint 的 :params")
(assert (= 512 (p2 :max_tokens)) "沒提到的欄位保留 endpoint 的值")

(def p3 (llm/build-payload pcfg @[] :params {:temperature 0.5} :temperature 0.9))
(assert (= 0.9 (p3 :temperature)) "具名參數蓋得掉 :params")

(def p4 (llm/build-payload pcfg @[] :temperature 0.9 :extra {:temperature 1.0 :seed 7}))
(assert (= 1.0 (p4 :temperature)) ":extra 優先序最高（維持原意：原樣併進 payload）")
(assert (= 7 (p4 :seed)) ":extra 可以塞 payload 沒有具名參數的欄位")

(def p5 (llm/build-payload pcfg @[] :max-tokens 64 :top-p 0.1))
(assert (= 64 (p5 :max_tokens)) ":max-tokens 對到 payload 的 max_tokens")
(assert (= 0.1 (p5 :top_p)) ":top-p 對到 payload 的 top_p")
(assert (= 0 ((llm/build-payload pcfg @[] :temperature 0) :temperature))
        "temperature 0 是有效值，不能被當成「沒給」")
(assert (= "m" (p1 :model)) "model 永遠來自 cfg")
(assert (string/find "缺 :model" (u/err-of |(llm/build-payload @{} @[]))))

# ── 自訂 headers 與 api-key ─────────────────────────────────────────
(def hcfg (llm/endpoint {:model "m" :api-key "sk-abc" :headers {"x-my-header" "v"}}))
(def hdrs (llm/headers-for hcfg))
(assert (= "Bearer sk-abc" (hdrs "authorization")) ":api-key 進 Authorization")
(assert (= "v" (hdrs "x-my-header")) "自訂 header 有帶上")
(assert (= "application/json" (hdrs "content-type")))
# 同名以使用者的為準（key 一律轉小寫比對）
(assert (= "Bearer 我自己的"
           ((llm/headers-for (llm/endpoint {:model "m" :headers {"Authorization" "Bearer 我自己的"}}))
             "authorization"))
        "自訂的 Authorization 蓋得掉預設那個")
# :headers 在 overrides 是**疊加**不是取代
(def h2 (llm/headers-for (llm/endpoint {:model "m" :headers {"a" "1"}} {:headers {"b" "2"}})))
(assert (and (= "1" (h2 "a")) (= "2" (h2 "b"))) ":headers 疊加")

# :api-key-env 從環境變數讀（用一個現場設的變數測，測完清掉）
(os/setenv "LLM_HTTP_TEST_KEY" "sk-from-env")
(assert (= "sk-from-env" ((llm/endpoint {:model "m" :api-key-env "LLM_HTTP_TEST_KEY"}) :api-key)))
(assert (llm/env-ready? {:api-key-env "LLM_HTTP_TEST_KEY"}))
(assert (not (llm/env-ready? {:api-key-env "LLM_HTTP_TEST_KEY_不存在"})))
(os/setenv "LLM_HTTP_TEST_KEY" nil)

(print "llm-http 參數合併測試通過 ✓")
