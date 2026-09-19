# 47 ① —— 一次 LLM 呼叫到底發生什麼事：組 payload、POST、解回應。
#
# 離線就能跑：同一個行程裡起一台假後端（fake-server.janet），不用金鑰、不用網路。
#   janet examples/agent-tutorial/47-api.janet
#
# 要打真模型：把下面 (llm/endpoint …) 的 :url 換成真位址、:api-key 換成真金鑰，
# 例如 :url "http://127.0.0.1:4000/v1/chat/completions"（litellm proxy），其餘一行都不用改。
#
# 教學：docs/47-llm-api-是什麼.md

(import spork/json)
(import ../../modules/llm-http/init :as llm)
(import ./fake-server :as fs)

(defn 分隔 [t] (print "\n── " t " " (string/repeat "─" (max 2 (- 56 (length t))))))

(defn main [&]
  (def 假 (fs/start :port 45821))
  (defer (fs/stop 假)

    # ① endpoint 設定：一張普通的 table，記著「打哪裡、用哪個 model、帶什麼金鑰」
    (def cfg (llm/endpoint {:model "fake-model"
                            :url (假 :url)
                            :api-key "sk-fake"}))

    # ② messages 是一個**陣列**，每則有 role 與 content。role 只有三種：
    #    system（你給模型的行為設定）、user（人講的）、assistant（模型講的）
    # ⚠ 這裡的字刻意用英文：spork/json 會把非 ASCII 逃逸成 \uXXXX，
    #    印出來滿滿的 \u4F60 會蓋掉重點。逃逸過的仍是合法 JSON，對端解得開。
    (def messages @[@{:role "system" :content "You are a terse assistant."}
                    @{:role "user"   :content "What is the weather in Taipei?"}])

    (分隔 "① 要送出去的 payload（這就是 HTTP body）")
    (def payload (llm/build-payload cfg messages :temperature 0.5 :max-tokens 128))
    (printf "POST %s" (cfg :url))
    (printf "Authorization: Bearer %s" (cfg :api-key))
    (print (json/encode payload "  " "\n"))

    (分隔 "② 後端回來的原始 JSON")
    (def res (llm/chat cfg messages :temperature 0.5 :max-tokens 128))
    (print (json/encode res "  " "\n"))

    (分隔 "③ 從回應裡挖出你要的東西")
    (printf "答案      = %s" (llm/reply-text res))
    (printf "為什麼停  = %s" (llm/reply-finish-reason res))
    (printf "用量      = %j" (get res :usage))
    (printf "被截斷了？= %q" (llm/truncated? res))

    (分隔 "④ ask：上面那一整套的一行式包裝")
    (print (llm/ask cfg "Say it again." "You are a terse assistant."))

    (分隔 "⑤ 假後端真的收到了幾次請求")
    (printf "收到 %d 次 POST，第一次的 model 欄位 = %s"
            (length (假 :log)) (get-in 假 [:log 0 :model]))))
