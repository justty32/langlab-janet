# agent：整條迴圈對著同行程的假後端跑——tool loop、多輪記憶、max-steps、usage 累計、trace、帶圖。
# 假後端的腳本在 agent-fake.janet（第一次回 tool_calls、拿到工具結果後回答案）。

(import ../modules/agent/init :as ag)
(import ./agent-fake :as fake)

(def port 45721)
(def srv (fake/start! port fake/standard-backend))
(def ep (fake/endpoint-spec port))

# ── 完整 tool loop：要 calc → 本地算 → 回答 ─────────────────────────
(def [tracer events] (ag/collect-tracer))
(def a (ag/make-agent {:endpoint ep :system "S" :tools [ag/calc-tool ag/now-tool] :trace tracer}))
(def out (ag/run a "1+2*3 是多少？"))
(assert (= "工具說：7" (out :text)) (string "答案：" (out :text)))
(assert (= 2 (out :steps)) "一步要工具、一步作答")
(assert (= :done (out :stopped-by)))
# 記憶：system → user → assistant(tool_calls) → tool → assistant
(assert (deep= @["system" "user" "assistant" "tool" "assistant"] (map |($ :role) (out :messages))))
(assert (= "call_1" (get-in out [:messages 3 :tool_call_id])) "tool_call_id 對得起來")
(assert (= "7" (get-in out [:messages 3 :content])) "本地工具真的算了")
# 送出去的 payload：有 tools 宣告、system 在第 0 則
(def first-req (fake/seen 0))
(assert (= 2 (length (first-req :tools))) "工具宣告有送出去")
(assert (= "calc" (get-in first-req [:tools 0 :function :name])))
(assert (= "S" (get-in first-req [:messages 0 :content])))
# usage：兩次呼叫各 10+5
(assert (= 20 (get-in out [:usage :prompt-tokens])))
(assert (= 10 (get-in out [:usage :completion-tokens])))
(assert (= 30 (get-in out [:usage :total-tokens])))
(assert (= 2 (get-in out [:usage :calls])))
(assert (deep= (out :usage) (out :run-usage)) "第一次 run：累計 = 本次")
# trace：model → tool → model → done
(assert (deep= @[:model :tool :model :done] (map |($ :kind) events)) (string/format "%q" (map |($ :kind) events)))
(assert (= "calc" (get-in events [1 :name])))
(assert (= "1+2*3" (get-in events [1 :args :expression])))
(assert (= "7" (get-in events [1 :result])))
(assert (number? (get-in events [1 :ms])) "有耗時")
(assert (= "tool_calls" (get-in events [0 :finish-reason])))
(assert (= 1 (get-in events [0 :tool-calls])))
(assert (= :done (get-in events [3 :stopped-by])))
# 每一筆事件都印得成一行人話
(each ev events (assert (string? (ag/format-event ev))))
(assert (string/find "→ calc(expression=1+2*3)" (ag/format-event (events 1))))

# ── 第二輪沿用同一份記憶，usage 繼續累計 ────────────────────────────
(def out2 (ag/run a "再問一次"))
(assert (= "工具說：7" (out2 :text)))
(assert (= 9 (length (out2 :messages))) "記憶延續：system ＋ 4 ＋ 4 則")
(assert (= 4 (get-in out2 [:usage :calls])) "累計 4 次呼叫")
(assert (= 2 (get-in out2 [:run-usage :calls])) "本次 2 次")
(assert (= 60 (get-in out2 [:usage :total-tokens])))

# ── 沒有工具：純問答，payload 不帶 :tools ───────────────────────────
(array/clear fake/seen)
(def plain (ag/make-agent {:endpoint ep}))
(def out3 (ag/run plain "嗨"))
(assert (= "收到：嗨" (out3 :text)))
(assert (= 1 (out3 :steps)))
(assert (nil? ((fake/seen 0) :tools)) "沒工具時不送 tools 欄位")
(assert (nil? (ag/system-of (plain :memory))) "沒給 system 就沒有")

# ── max-steps：假後端沒拿到工具結果前一直要工具；把工具拿掉它就永遠要 ──
(ag/deftool silent "回空字串的工具" {:type "object" :properties {}} [_] nil)
(def [tr2 ev2] (ag/collect-tracer))
# 另起一台「不管收到什麼都要工具」的假後端，模擬模型鬼打牆
(defn always-tools [_] (fake/reply-tools [(fake/tool-call "c" "silent" {})]))
(def srv2 (fake/start! 45722 always-tools))
(def stuck2 (ag/make-agent {:endpoint (fake/endpoint-spec 45722) :tools [silent] :max-steps 3 :trace tr2}))
(def out4 (ag/run stuck2 "x"))
(assert (= :max-steps (out4 :stopped-by)) "撞頂要標出來")
(assert (nil? (out4 :text)) "沒有最終答案")
(assert (= 3 (out4 :steps)))
(assert (= :max-steps (get-in ev2 [(dec (length ev2)) :stopped-by])) "trace 的 done 也寫 max-steps")
(:close srv2)

# ── 記憶截斷在 run 結束時發生：max-turns 1 → 只剩最後一輪，配對完整 ──
(def small (ag/make-agent {:endpoint ep :system "S" :tools [ag/calc-tool] :max-turns 1}))
(ag/run small "第一問")
(def out5 (ag/run small "第二問"))
(assert (deep= @["system" "user" "assistant" "tool" "assistant"] (map |($ :role) (out5 :messages)))
        "只留最後一輪，tool_calls 與 tool 一起留")
(assert (= "第二問" (get-in out5 [:messages 1 :content])))

# ── 帶圖：走 llm-http 的 user-message，content 變 parts ──────────────
(array/clear fake/seen)
(def out6 (ag/run plain "這是什麼？" :images ["http://127.0.0.1/a.png"]))
(def sent ((last ((fake/seen 0) :messages)) :content))
(assert (indexed? sent) "帶圖時 content 是 parts 陣列")
(assert (= "image_url" (get-in sent [1 :type])))
(assert (= "收到：這是什麼？" (out6 :text)) "假後端從 parts 裡撈得到文字")

# ── 沿用讀回的記憶：:memory 給既有的那份，system 不會被蓋掉 ──────────
(def mem (ag/make-memory :system "舊的"))
(ag/append! mem @{:role "user" :content "以前問的"})
(ag/append! mem @{:role "assistant" :content "以前答的"})
(def resumed (ag/make-agent {:endpoint ep :system "新的" :memory mem}))
(assert (= "舊的" (ag/system-of (resumed :memory))) "記憶裡已有 system 時 :system 被忽略")
(assert (= 5 (length ((ag/run resumed "續問") :messages))) "接在舊歷史後面")

# ── endpoint 名字打錯 ───────────────────────────────────────────────
(def [ok e] (protect (ag/make-agent {:endpoint "沒這個"})))
(assert (and (not ok) (string/find "沒有這個 endpoint" (string e))))

(:close srv)
(print "agent 迴圈（假後端）測試通過 ✓")
