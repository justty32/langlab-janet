# 47 ② —— system prompt 與多輪對話：模型的「記憶」其實是你每次重送的歷史。
#
# 離線可跑：janet examples/agent-tutorial/47b-multi-turn.janet
# 要打真模型：把 (llm/endpoint …) 的 :url／:api-key 換掉即可。
#
# 教學：docs/47b-多輪對話.md

(import ../../modules/llm-http/init :as llm)
(import ./fake-server :as fs)

(defn 分隔 [t] (print "\n── " t " " (string/repeat "─" (max 2 (- 50 (length t))))))

# 假後端的規則刻意做得很笨，好讓「記憶從哪來」無所遁形：
# 它只是在**這次收到的 messages 裡**找有沒有「名字是小明」這句話。
(defn 回應 [payload _n]
  (def 全文 (string/join (map |(string (get $ :content "")) (payload :messages)) " "))
  (def 有系統 (= "system" (get-in payload [:messages 0 :role])))
  [200 (fs/text-reply
         (cond
           (not (string/find "名字是小明" 全文)) "（假後端）我不知道你的名字。"
           有系統 "（假後端）回稟主人，您叫小明。"
           "（假後端）你叫小明。")
         :prompt-tokens (* 4 (length (payload :messages))))])

(defn 問 [cfg 歷史 說什麼]
  "把一句話加進歷史、送出去、再把模型的回答也記回歷史。"
  (array/push 歷史 @{:role "user" :content 說什麼})
  (def res (llm/chat cfg 歷史))
  (def 答 (llm/reply-text res))
  (array/push 歷史 @{:role "assistant" :content 答})
  (printf "  你 → %s" 說什麼)
  (printf "  模 → %s   （這次送出 %d 則訊息，prompt_tokens=%d）"
          答 (dec (length 歷史)) (get-in res [:usage :prompt_tokens]))
  答)

(defn 截斷
  ``只留 system ＋ 最後 n 則。⚠ 別把 assistant 的 tool_calls 跟它對應的 role:"tool"
  切開——切開了下一次請求就對不起來。所以一次砍一對，別砍單數。``
  [歷史 n]
  (def sys (if (= "system" (get-in 歷史 [0 :role])) [(歷史 0)] []))
  (def 其餘 (array/slice 歷史 (length sys)))
  (array ;sys ;(array/slice 其餘 (- (inc (min n (length 其餘)))))))

(defn main [&]
  (def 假 (fs/start :port 45822 :reply 回應))
  (defer (fs/stop 假)
    (def cfg (llm/endpoint {:model "fake-model" :url (假 :url) :api-key "sk-fake"}))

    (分隔 "① 不帶歷史：每次都是第一次見面")
    (問 cfg @[] "我的名字是小明。")
    (問 cfg @[] "我叫什麼名字？")

    (分隔 "② 帶歷史：同一個陣列一直長")
    (def 歷史 @[])
    (問 cfg 歷史 "我的名字是小明。")
    (問 cfg 歷史 "我叫什麼名字？")
    (printf "  歷史現在 %d 則：%s" (length 歷史)
            (string/join (map |(get $ :role) 歷史) " → "))

    (分隔 "③ system prompt：插在最前面，每次都要重送")
    (def 歷史2 @[@{:role "system" :content "你是古代的管家，講話很恭敬。"}])
    (問 cfg 歷史2 "我的名字是小明。")
    (問 cfg 歷史2 "我叫什麼名字？")

    (分隔 "④ 歷史會無限長大 → 自己截斷")
    (def 長 @[@{:role "system" :content "S"}])
    (for i 0 5
      (array/push 長 @{:role "user" :content (string "第 " i " 句")})
      (array/push 長 @{:role "assistant" :content (string "回 " i)}))
    (printf "  截斷前 %d 則：%s" (length 長)
            (string/join (map |(get $ :content) 長) " "))
    (def 短 (截斷 長 4))
    (printf "  截斷後 %d 則：%s" (length 短)
            (string/join (map |(get $ :content) 短) " "))))
