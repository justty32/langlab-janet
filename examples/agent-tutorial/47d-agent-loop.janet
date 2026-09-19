# 47 ④ —— 自己手寫 agent loop（十七行），再對照 with-tools 多做了什麼。
#
# 所謂 agent 就是這個 while：問模型 → 它要工具就執行 → 結果餵回去 → 再問，
# 直到它不要工具為止。沒有魔法。
#
# 離線可跑：janet examples/agent-tutorial/47d-agent-loop.janet
# 教學：docs/47d-自己寫-agent-loop.md

(import spork/json)
(import ../../modules/llm-http/init :as llm)
(import ./fake-server :as fs)

(defn 分隔 [t] (print "\n── " t " " (string/repeat "─" (max 2 (- 50 (length t))))))

# ── 這就是全部：十七行的 agent loop ──────────────────────────────
(defn 跑一輪到底 [cfg 歷史 tools handlers &opt 上限]
  (default 上限 8)
  (var 答 nil)
  (var 輪 0)
  (while (< 輪 上限)
    (++ 輪)
    (def msg (llm/reply-message (llm/chat cfg 歷史 :tools tools)))
    (array/push 歷史 msg)                       # 整則原樣接回去，含 tool_calls
    (def calls (get msg :tool_calls))
    (if (or (nil? calls) (empty? calls))
      (do (set 答 (get msg :content)) (break))   # 沒要工具 → 這就是答案
      (each c calls
        (def args (json/decode (get-in c [:function :arguments]) true))
        (def r ((get handlers (get-in c [:function :name])) args))
        (array/push 歷史 @{:role "tool"
                           :tool_call_id (get c :id)
                           :content (string (json/encode r))}))))
  [答 輪])

(def tools [(llm/tool-spec "get_weather" "Current weather of a city"
                           {:type "object"
                            :properties {:city {:type "string"}}
                            :required ["city"]})])
(def handlers {"get_weather" (fn [args] {:city (get args :city) :temp_c 31})})

# 一直要工具、永遠不作答的假後端——用來看 max-rounds 有沒有在擋
(defn 鬼打牆 [_payload n]
  [200 (fs/tool-call-reply "get_weather" {:city "Taipei"} (string "call_" n))])

(defn main [&]
  (def 假 (fs/start :port 45824))
  (def cfg (llm/endpoint {:model "fake-model" :url (假 :url) :api-key "sk-fake"}))

  (defer (fs/stop 假)
    (分隔 "① 自己寫的 loop")
    (def 歷史 @[@{:role "user" :content "What is the weather in Taipei?"}])
    (def [答 輪] (跑一輪到底 cfg 歷史 tools handlers))
    (printf "答案 = %s" 答)
    (printf "打了 %d 輪，歷史 %d 則：%s"
            輪 (length 歷史) (string/join (map |(get $ :role) 歷史) " → "))

    (分隔 "② 同一件事交給 with-tools")
    (def out (llm/with-tools cfg
                             @[@{:role "user" :content "What is the weather in Taipei?"}]
                             tools handlers
                             :system "你只回一句話。"
                             :max-rounds 8
                             :trace (fn [n args r] (printf "  trace：模型要 %s %j → %s" n args r))))
    (printf "答案 = %s" (out :text))
    (printf "rounds = %d  exhausted = %q  歷史 %d 則（多了那則 system）"
            (out :rounds) (out :exhausted) (length (out :messages)))
    (printf "roles = %s" (string/join (map |(get $ :role) (out :messages)) " → ")))

  (分隔 "③ with-tools 多做的第三件事：max-rounds 防呆")
  (def 假2 (fs/start :port 45825 :reply 鬼打牆))
  (defer (fs/stop 假2)
    (def cfg2 (llm/endpoint {:model "fake-model" :url (假2 :url) :api-key "sk-fake"}))
    (def out2 (llm/with-tools cfg2 @[@{:role "user" :content "hi"}]
                              tools handlers :max-rounds 3))
    (printf "模型永遠不作答時：rounds=%d exhausted=%q text=%q"
            (out2 :rounds) (out2 :exhausted) (out2 :text))
    (print "  ⚠ 沒有這道上限，這個 while 會一直打下去——真模型上就是一直燒錢。")))
