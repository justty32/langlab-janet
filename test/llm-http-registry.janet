# llm-http：endpoint registry —— 內建四筆、inline endpoint、註冊／移除、設定驗證。
#
# 全部是純函式，不碰網路。
# ⚠ 一開頭就 reset-endpoints!：使用者本機可能有 ~/.config/llm-http/endpoints.janet
#   會被 import 時自動載入，測試要先把 registry 打回「只剩內建四筆」才有確定性。

(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

# ── 內建四筆 ────────────────────────────────────────────────────────
(assert (deep= @["claude" "deepseek" "local" "openrouter"] (llm/endpoint-names))
        "reset 之後只剩內建四個 endpoint")
(assert (deep= @["claude" "deepseek" "local" "openrouter"] (llm/builtin-names)))
(assert (llm/builtin-endpoint? "local"))
(assert (= :builtin (llm/endpoint-source "local")))

(def local (llm/endpoint "local"))
(assert (= "local" (local :model)))
(assert (string/has-prefix? "http://127.0.0.1:" (local :url)) "預設 base 是 127.0.0.1")
(assert (string/has-suffix? "/v1/chat/completions" (local :url)))
(assert (local :vision?) "local 指到 gemma-4，吃圖")
(assert (not ((llm/endpoint "deepseek") :vision?)) "deepseek 純文字")
(assert (= "ANTHROPIC_API_KEY" ((llm/endpoint "claude") :env)))
(assert (= "OPENROUTER_API_KEY" ((llm/endpoint "openrouter") :env)))
(assert (nil? (llm/endpoint "沒這個")) "名字打錯回 nil（不是丟例外）")

# specs 仍然是「名字 → 設定」的表，舊讀法照舊
(assert (= "local" (get-in llm/specs ["local" :model])) "specs 讀法不變")
(assert (= "local" (get-in llm/builtin-specs ["local" :model])) "builtin-specs 也還在")

# overrides：換 model、換 base，而且不污染下一次
(assert (= "qwen" ((llm/endpoint "local" {:model "qwen"}) :model)))
(assert (= "local" ((llm/endpoint "local") :model)) "overrides 不污染下一次")
(assert (= "http://127.0.0.1:9999/v1/chat/completions"
           ((llm/endpoint "local" {:base "http://127.0.0.1:9999"}) :url)))
# base 結尾多打的 / 會被吃掉
(assert (= "http://127.0.0.1:9999/v1/chat/completions"
           (llm/chat-url "http://127.0.0.1:9999/")))

# 不需要金鑰的 endpoint 一律 ready
(assert (llm/env-ready? "local"))
(assert (llm/env-ready? "根本沒這個名字") "不認得的名字不該說沒 ready")

# ── (a) 直接拿一張 table 當 endpoint，完全不註冊 ────────────────────
(def inline (llm/endpoint {:model "qwen3" :base "http://127.0.0.1:4111" :vision? true}))
(assert (= "qwen3" (inline :model)))
(assert (= "http://127.0.0.1:4111/v1/chat/completions" (inline :url)))
(assert (inline :vision?))
(assert (deep= @["claude" "deepseek" "local" "openrouter"] (llm/endpoint-names))
        "inline endpoint 不會被偷偷註冊進 registry")

# :url 給了就完全繞過 base（拿來直接打 LM Studio）
(def direct (llm/endpoint {:model "g" :url "http://127.0.0.1:1234/v1/chat/completions"}))
(assert (= "http://127.0.0.1:1234/v1/chat/completions" (direct :url)))
# overrides 的 :url 又贏過 spec 的 :url
(assert (= "http://127.0.0.1:7/x"
           ((llm/endpoint {:model "g" :url "http://a/b"} {:url "http://127.0.0.1:7/x"}) :url)))

# ── 設定的驗證錯誤要是看得懂的中文，而且在打 HTTP 之前就爆 ──────────
(assert (string/find "缺 :model" (u/err-of |(llm/endpoint {:base "http://x"})))
        "沒有 :model 要講「缺 :model」")
(assert (string/find "不認得的欄位" (u/err-of |(llm/endpoint {:model "m" :vision true})))
        ":vision? 打成 :vision 要被擋下來")
(assert (string/find ":params 必須是一張表"
                     (u/err-of |(llm/endpoint {:model "m" :params "溫度0.2"}))))
(assert (string/find ":model 必須是字串" (u/err-of |(llm/endpoint {:model 42}))))
(assert (string/find "要嘛是名字字串" (u/err-of |(llm/endpoint 42))))

# ── (b) 註冊成有名字的 endpoint ─────────────────────────────────────
(llm/define-endpoint "qwen" {:model "qwen3" :params {:temperature 0.2}})
(assert (= "qwen3" ((llm/endpoint "qwen") :model)))
(assert (= 0.2 (get-in (llm/endpoint "qwen") [:params :temperature])))
(assert (not (llm/builtin-endpoint? "qwen")) "自訂的不算內建")
(assert (= :runtime (llm/endpoint-source "qwen")))
(assert (find |(= "qwen" $) (llm/endpoint-names)) "註冊完就出現在名單裡")
(assert (llm/undefine-endpoint! "qwen"))
(assert (nil? (llm/endpoint "qwen")) "拿掉之後就查不到了")

(llm/reset-endpoints!)
(print "llm-http registry 測試通過 ✓")
