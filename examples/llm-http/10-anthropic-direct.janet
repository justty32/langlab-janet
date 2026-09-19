# llm-http 範例 ⑩ —— 直打 Anthropic Messages API，不經 litellm proxy。
#
# 內建 endpoint claude-direct：:api :anthropic（本機做 OpenAI ↔ Anthropic 雙向轉換）＋
# :transport :curl（https 靠 curl）。轉換是透明的：ask／chat／with-tools／ask-json 一行不用改。
#
# 前半段**不需要金鑰也不需要網路**：把轉換出來的 request 印給你看。
# 後半段真的打 api.anthropic.com，要 ANTHROPIC_API_KEY；沒設就印提示跳過。
# ⚠ 這條線本機沒 key，真打那段未實測（假伺服器的 tool loop 在 test/llm-http-anthropic-loop.janet 驗過）。
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/10-anthropic-direct.janet
#   ANTHROPIC_API_KEY=sk-ant-… janet examples/llm-http/10-anthropic-direct.janet

(import spork/json)
(import ../../modules/llm-http/init :as llm)

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok (flush) (eprintf "✗ %s 失敗：\n   %s" label v))
  (if ok v))

(defn main [& _]
  # ── ① 看 endpoint 長什麼樣 ────────────────────────────────────────
  (def cfg (llm/endpoint "claude-direct"))
  (print "── ① claude-direct 這份 cfg ──")
  (printf "  model=%s api=%q transport=%q" (cfg :model) (cfg :api) (cfg :transport))
  (printf "  url=%s" (cfg :url))
  (printf "  金鑰讀自 ANTHROPIC_API_KEY：%s" (if (llm/env-ready? "claude-direct") "已設" "⚠ 未設"))

  # ── ② 純函式：OpenAI 形狀 → Anthropic request（不打網路）──────────
  (print "\n── ② to-anthropic：OpenAI payload 轉出去長怎樣 ──")
  (def payload (llm/build-payload cfg
                                  @[@{:role "system" :content "只用繁體中文"}
                                    @{:role "user" :content "台北天氣？"}]
                                  :tools llm/demo-tools :max-tokens 300))
  (def req (llm/to-anthropic payload))
  (printf "  system 抽到頂層：%s" (req :system))   # ⚠ 不用 %q，中文會被逃逸成 \\xE5…
  (printf "  max_tokens：%q（Anthropic 必填，沒給會補 %d）" (req :max_tokens) llm/default-max-tokens)
  (printf "  tools[0] 的欄位：%q" (sorted (keys (get-in req [:tools 0]))))
  (printf "  messages 剩 %d 則（system 拿掉了）" (length (req :messages)))

  # ── ③ 純函式：Anthropic 回應 → OpenAI 形狀（不打網路）──────────────
  (print "\n── ③ from-anthropic：Anthropic 回應轉回來長怎樣 ──")
  (def fake {:id "msg_x" :model "claude-sonnet-5" :stop_reason "tool_use"
             :content [{:type "text" :text "我查一下。"}
                       {:type "tool_use" :id "toolu_1" :name "get_weather" :input {:city "台北"}}]
             :usage {:input_tokens 30 :output_tokens 12}})
  (def res (llm/from-anthropic fake))
  (printf "  reply-text          = %s" (llm/reply-text res))
  (printf "  reply-finish-reason = %q（tool_use → tool_calls）" (llm/reply-finish-reason res))
  (printf "  tool_calls[0].function.arguments = %q（回到 JSON 字串）"
          (get-in (llm/reply-message res) [:tool_calls 0 :function :arguments]))
  (printf "  reply-usage         = %q" (llm/reply-usage res))

  # ── ④ 真的打 —— 要 ANTHROPIC_API_KEY ─────────────────────────────
  (print "\n── ④ 真打 api.anthropic.com ──")
  (cond
    (not (llm/env-ready? "claude-direct"))
    (print "  跳過：ANTHROPIC_API_KEY 沒設。設了再跑一次，這段會用 ask 問一句、再用 with-tools 跑一輪工具。")
    (not (llm/curl-available?))
    (print "  跳過：PATH 上沒有 curl（https 靠它）。")
    (do
      (when-let [a (attempt "ask" |(llm/ask cfg "用一句話說明你是誰。" nil nil :max-tokens 100))]
        (printf "  ask → %s" a))
      (when-let [out (attempt "with-tools"
                              |(llm/with-tools cfg @[@{:role "user" :content "台北現在天氣？用工具查"}]
                                               llm/demo-tools llm/demo-handlers
                                               :max-tokens 300
                                               :trace (fn [n a r] (eprintf "  → 工具 %s %q" n a))))]
        (printf "  with-tools（%d 輪）→ %s" (out :rounds) (out :text))))))
