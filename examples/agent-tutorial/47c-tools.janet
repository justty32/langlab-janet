# 47 ③ —— tool calling 的四步，一步一步印出來。
#
# 重點：模型**不會執行任何東西**。它只是回一段「請幫我叫 get_weather，參數是這些」的 JSON，
# 真正去查天氣的是你的程式；查完再用 role:"tool" 的訊息把結果送回去，它才作答。
#
# 離線可跑：janet examples/agent-tutorial/47c-tools.janet
# 教學：docs/47c-tool-calling.md

(import spork/json)
(import ../../modules/llm-http/init :as llm)
(import ./fake-server :as fs)

(defn 分隔 [t] (print "\n── " t " " (string/repeat "─" (max 2 (- 50 (length t))))))

# ── 你這邊真正會被執行的函式 ─────────────────────────────────────
(defn 查天氣 [args]
  (def city (get args :city "?"))
  (if (= city "Mars") (error "沒有火星的觀測站")
    {:city city :temp_c 31 :cond "sunny"}))

(defn 執行工具
  ``⚠ 一定要 protect：handler 自己炸掉時，要把錯誤**當成工具結果送回模型**，
  而不是讓整條 loop 掛掉。模型看得懂錯誤訊息，通常會換參數重試或改口。``
  [name args]
  (def [ok v] (protect (case name
                         "get_weather" (查天氣 args)
                         (error (string "沒有名為 " name " 的工具")))))
  (if ok (if (string? v) v (string (json/encode v)))
    (string "工具執行失敗：" v)))

(defn main [&]
  (def 假 (fs/start :port 45823))
  (defer (fs/stop 假)
    (def cfg (llm/endpoint {:model "fake-model" :url (假 :url) :api-key "sk-fake"}))

    (分隔 "① 宣告工具：一份 JSON schema")
    # ⚠ schema 裡的字刻意用英文：spork/json 把非 ASCII 逃逸成 \uXXXX，
    #    印出來會被 \u57CE\u5E02 蓋掉重點（逃逸過仍是合法 JSON，對端解得開）。
    (def tools [(llm/tool-spec "get_weather" "Current weather of a city"
                               {:type "object"
                                :properties {:city {:type "string"
                                                    :description "city name"}}
                                :required ["city"]})])
    (print (json/encode tools "  " "\n"))

    (分隔 "② 送出去，看模型回什麼")
    (def 歷史 @[@{:role "user" :content "What is the weather in Taipei?"}])
    (def res (llm/chat cfg 歷史 :tools tools))
    (def msg (llm/reply-message res))
    (printf "finish_reason = %s" (llm/reply-finish-reason res))
    (printf "content       = %q   ← 沒有答案，它在等工具結果" (get msg :content))
    (print  "tool_calls    =")
    (print (json/encode (get msg :tool_calls) "  " "\n"))

    (分隔 "③ 本地執行，結果用 role:\"tool\" 送回去")
    # ★ 整則 assistant 訊息原樣接回歷史：tool_calls 那段是後面 role:"tool" 的錨點，
    #   只留 content 會讓下一次請求對不起來。
    (array/push 歷史 msg)
    (each c (get msg :tool_calls)
      (def name (get-in c [:function :name]))
      # ⚠ arguments 是**一段 JSON 字串**，不是巢狀物件，要再 decode 一次
      (def raw (get-in c [:function :arguments]))
      (def args (json/decode raw true))
      (printf "arguments 原文 = %q  （字串！）" raw)
      (printf "decode 之後    = %q" args)
      (def 結果 (執行工具 name args))
      (printf "本地執行結果   = %s" 結果)
      (array/push 歷史 @{:role "tool" :tool_call_id (get c :id) :content 結果}))

    (分隔 "④ 再送一次，模型才作答")
    (def res2 (llm/chat cfg 歷史 :tools tools))
    (array/push 歷史 (llm/reply-message res2))
    (printf "答案 = %s" (llm/reply-text res2))
    (printf "歷史四則：%s" (string/join (map |(get $ :role) 歷史) " → "))

    (分隔 "⑤ handler 丟例外：錯誤字串照樣送回模型")
    (printf "%s" (執行工具 "get_weather" @{:city "Mars"}))
    (printf "%s" (執行工具 "launch_missile" @{}))))
