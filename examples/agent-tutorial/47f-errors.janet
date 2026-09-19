# 47 ⑥ —— 打真模型一定會遇到的六種狀況，外加怎麼估成本。
#
# 離線可跑：janet examples/agent-tutorial/47f-errors.janet
# 教學：docs/47f-錯誤與成本.md
#
# 完整的重試／逾時寫法在 snippets/retry-timeout.janet，這裡只示範最小版。

(import ../../modules/llm-http/init :as llm)
(import ./fake-server :as fs)

(defn 分隔 [t] (print "\n── " t " " (string/repeat "─" (max 2 (- 50 (length t))))))

(var 第幾次打-flaky 0)

# 假後端：用 :model 決定要扮演哪一種故障
(defn 回應 [payload _n]
  (case (payload :model)
    "bad-key" [401 {:error {:message "Incorrect API key provided" :type "invalid_request_error"}}]
    "busy"    [429 {:error {:message "Rate limit reached" :type "rate_limit_error"}}]
    "flaky"   (do (++ 第幾次打-flaky)
                (if (< 第幾次打-flaky 3)
                  [429 {:error {:message "Rate limit reached"}}]
                  [200 (fs/text-reply "(fake) third time lucky")]))
    (fs/default-reply payload _n)))

(defn 看看會怎樣 [標題 f]
  (def [ok v] (protect (f)))
  (printf "%s：" 標題)
  (if ok (printf "  ✓ %s" v)
    (each line (string/split "\n" (string v)) (print "  ✗ " line))))

(defn 重試
  ``最小版重試：失敗就退避再來。⚠ 真的要用請看 snippets/retry-timeout.janet——
  那邊有 jitter（一群 client 同時失敗會同時重試）與「哪些錯誤根本不該重試」。``
  [次數 f]
  (var 成功? false)
  (var 結果 nil)
  (for n 0 次數
    (def [ok v] (protect (f)))
    (when ok (set 成功? true) (set 結果 v) (break))
    (set 結果 v)
    (printf "  第 %d 次失敗，等 %.2f 秒再來" (inc n) (* 0.05 (math/pow 2 n)))
    (when (< n (dec 次數)) (ev/sleep (* 0.05 (math/pow 2 n)))))
  # ⚠ 一定要用明確的旗標：只靠「結果是不是錯誤」判斷，第三次成功時會誤判
  (if 成功? 結果 (error 結果)))

(defn main [&]
  (def 假 (fs/start :port 45827 :reply 回應))
  (defer (fs/stop 假)
    (defn cfg-of [model] (llm/endpoint {:model model :url (假 :url) :api-key "sk-fake"}))

    (分隔 "① 連不上：對方根本沒起來")
    # ⚠ 連本機一律寫 127.0.0.1 不要寫 localhost（::1 陷阱）
    (看看會怎樣 "打一個沒人聽的 port"
                |(llm/ask (llm/endpoint {:model "m" :base "http://127.0.0.1:45799"}) "嗨"))

    (分隔 "② 401：金鑰不對")
    (看看會怎樣 "金鑰錯" |(llm/ask (cfg-of "bad-key") "嗨"))

    (分隔 "③ 429：打太快")
    (看看會怎樣 "被限流" |(llm/ask (cfg-of "busy") "嗨"))

    (分隔 "④ 429 之後重試：第三次成功")
    (def out (重試 4 |(llm/ask (cfg-of "flaky") "嗨")))
    (printf "  最後拿到：%s" out)

    (分隔 "⑤ 截斷：HTTP 200，但答案是半截的")
    (def res (llm/chat (cfg-of "fake-model") @[@{:role "user" :content "很長的問題"}]
                       :max-tokens 8))
    (printf "HTTP 是 200，finish_reason = %s，truncated? = %q"
            (llm/reply-finish-reason res) (llm/truncated? res))
    (printf "content = %q   ← 空字串不是 nil，一路過關到你手上" (llm/reply-text res))
    (printf "usage   = %j" (get res :usage))
    (print "★ 推理模型會先把預算花在 reasoning_tokens 上，max_tokens 給小了就什麼都不剩。")
    (看看會怎樣 "ask 遇到這種情況會講清楚"
                |(llm/ask (cfg-of "fake-model") "很長的問題" nil nil :max-tokens 8))

    (分隔 "⑥ 累計 usage 估成本")
    # 價格自己填（各家單位都是「每百萬 token 多少錢」）
    (def 每百萬-輸入 0.15)
    (def 每百萬-輸出 0.60)
    (def 帳 @{:in 0 :out 0})
    (for i 0 3
      (def r (llm/chat (cfg-of "fake-model") @[@{:role "user" :content "hi"}]))
      (def u (get r :usage))
      (update 帳 :in + (get u :prompt_tokens 0))
      (update 帳 :out + (get u :completion_tokens 0)))
    (printf "三次呼叫：輸入 %d token、輸出 %d token" (帳 :in) (帳 :out))
    (printf "估價 = %.6f 美元"
            (+ (* (/ (帳 :in) 1000000) 每百萬-輸入)
               (* (/ (帳 :out) 1000000) 每百萬-輸出)))
    (print "⚠ 多輪 tool loop 每一輪都重送整份歷史，輸入 token 會平方成長。")))
