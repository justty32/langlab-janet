# 第 2 步的驗收：對話記憶、reset、失敗不污染 history、remember=false
#
#   janet try/test-llm.janet
#
# ⚠ 需要 litellm proxy 在 127.0.0.1:4000 跑著。
# ⚠ 模型挑 ollama-qwen2.5-14b 不挑 gemma3-1b：1B 的模型記不住東西，
#   測到「答錯」時你分不清是 history 沒送出去還是模型太笨。

(import ./llm)

(def bot (llm/new :model "ollama-qwen2.5-14b"
                  :system "用繁體中文，一句話回答。"))

# ① 記得住
(print "1> " (llm/ask bot "我的幸運數字是 4173，記住它"))
(print "2> " (llm/ask bot "我的幸運數字是多少？"))       # ← 要答得出 4173
(printf "   history %d 則（應該 4）\n" (length (bot :history)))

# ② reset 清歷史但留 system
(llm/reset bot)
(printf "   reset 後 history %d 則（應該 0）" (length (bot :history)))
(print "3> " (llm/ask bot "我的幸運數字是多少？"))       # ← 這次要答不出來

# ③ 失敗不能污染 history
(def n (length (bot :history)))
(def [ok _] (protect (llm/ask bot "hi" :model "no-such-model")))
(printf "   壞掉的呼叫 ok=%q（應該 false）" ok)
(printf "   失敗後 history 應該還是 %d，實際 %d\n" n (length (bot :history)))

# ④ remember=false 不留痕跡
(def m (length (bot :history)))
(print "4> " (llm/ask bot "隨便說個顏色" :remember false))
(printf "   history 應該還是 %d，實際 %d" m (length (bot :history)))
