# agent 迴圈 —— make-agent 組一個 agent，run 跑到模型不再叫工具為止。
#
# 站在 llm-http 上面：這裡只用它的公開 API（endpoint／chat／reply-message／
# reply-finish-reason／user-message），工具怎麼執行走本模組的 registry/call-tool
# （行為跟 llm-http/with-tools 一致：handler 丟例外 → 錯誤字串回給模型）。
#
# 為什麼不直接呼叫 llm-http/with-tools：agent 要的三件事它沒有——每一步的 usage 累計、
# 每個工具的耗時、跨多次 run 沿用同一份記憶（with-tools 每次都複製 messages）。
#
# 一次 run 的流程：
#   user 訊息進記憶 → 打模型 → 整則 assistant 訊息接回記憶
#     → 有 tool_calls：逐個執行、role:"tool" 結果接回記憶、回到「打模型」
#     → 沒有：content 就是答案，停
#   撞到 :max-steps 就停，:stopped-by 會是 :max-steps（:text 是 nil）
#   結束前 trim! 一次記憶（整輪整輪丟，不拆散 tool_calls 配對，見 memory.janet）

(import ../llm-http/init :as llm)
(import ./registry :as reg)
(import ./memory :as mem)

(defn- resolve-endpoint
  "名字字串／設定 table／已經 resolve 過的 cfg 都收；找不到名字就丟中文錯誤。"
  [ep]
  (def cfg (llm/endpoint (or ep "local")))
  (unless cfg
    (error (string "沒有這個 endpoint：" ep "（可用：" (string/join (llm/endpoint-names) "、") "）")))
  cfg)

(defn make-agent
  ``組一個 agent，回一張 table（之後 run 都拿它）。opts 認得的 key：

    :endpoint   endpoint 名字（"local"）或設定 table；省略＝"local"
    :system     system 訊息
    :tools      工具陣列（make-tool／deftool／default-tools 做的）；省略＝沒有工具
    :max-steps  一次 run 最多打幾次模型，預設 10
    :trace      (fn [事件]) 每一步叫一次；省略＝安靜。現成的在 trace.janet
    :memory     沿用一份既有的記憶（memory-io/load 讀回來的）；省略就新開一份
    :max-turns :max-chars  轉給 make-memory（截斷門檻）
    :temperature :max-tokens :params  原樣轉給每一次 llm-http/chat``
  [opts]
  (def tools (reg/as-table (get opts :tools [])))
  (def memory (or (get opts :memory)
                  (mem/make-memory :max-turns (get opts :max-turns)
                                   :max-chars (get opts :max-chars))))
  (when-let [s (get opts :system)]
    (when (and (not (empty? s)) (nil? (mem/system-of memory)))
      (mem/set-system! memory s)))
  @{:cfg         (resolve-endpoint (get opts :endpoint))
    :memory      memory
    :tools       tools
    :specs       (reg/tools->specs tools)
    :max-steps   (get opts :max-steps 10)
    :trace       (or (get opts :trace) (fn [_] nil))
    :temperature (get opts :temperature)
    :max-tokens  (get opts :max-tokens)
    :params      (get opts :params)
    :usage       @{:prompt-tokens 0 :completion-tokens 0 :total-tokens 0 :calls 0}})

(defn- add-usage!
  "把一次回應的 :usage 加進 acc（缺欄位就當 0）。"
  [acc u]
  (when u
    (+= (acc :prompt-tokens)     (or (get u :prompt_tokens) 0))
    (+= (acc :completion-tokens) (or (get u :completion_tokens) 0))
    (+= (acc :total-tokens)      (or (get u :total_tokens)
                                     (+ (or (get u :prompt_tokens) 0)
                                        (or (get u :completion_tokens) 0)))))
  (++ (acc :calls))
  acc)

(defn- ms-since [t0] (* 1000 (- (os/clock) t0)))

(defn- run-tools!
  "執行一則 assistant 訊息裡的所有 tool_calls，結果逐個接回記憶。"
  [agent step calls]
  (each c calls
    (def name (get-in c [:function :name]))
    (def args (reg/decode-args (get-in c [:function :arguments])))
    (def t0 (os/clock))
    (def result (reg/call-tool (agent :tools) name args))
    ((agent :trace) @{:kind :tool :step step :name name :args args
                      :result result :ms (ms-since t0)})
    (mem/append! (agent :memory)
                 @{:role "tool" :tool_call_id (get c :id) :content result})))

(defn run
  ``跟 agent 說一句話，跑到它給出最終答案（或撞到 :max-steps）。可以重複呼叫，記憶會延續。

  :images 可省略的圖檔路徑／URL 陣列，走 llm-http 的 user-message（⚠ endpoint 要吃圖）。

  回 @{:text 答案字串（撞上限時 nil） :steps 打了幾次模型 :stopped-by :done 或 :max-steps
       :usage 這個 agent **累計**的 token 用量 :run-usage 這一次 run 的用量
       :messages 記憶裡的訊息陣列（同一個陣列，不是複本）}``
  [agent input &named images]
  (def m (agent :memory))
  (def trace (agent :trace))
  (def run-usage @{:prompt-tokens 0 :completion-tokens 0 :total-tokens 0 :calls 0})
  (def specs (if (empty? (agent :specs)) nil (agent :specs)))
  (mem/append! m (llm/user-message input images))
  (var steps 0)
  (var text nil)
  (var stopped :max-steps)
  (while (< steps (agent :max-steps))
    (++ steps)
    (def t0 (os/clock))
    (def res (llm/chat (agent :cfg) (mem/messages m)
                       :tools specs
                       :temperature (agent :temperature) :max-tokens (agent :max-tokens)
                       :params (agent :params)))
    (add-usage! (agent :usage) (get res :usage))
    (add-usage! run-usage (get res :usage))
    (def msg (llm/reply-message res))
    (unless msg (error (string "回應裡沒有 message：" (string/format "%q" res))))
    (mem/append! m msg)                              # ★ 整則原樣接回（含 tool_calls）
    (def calls (or (get msg :tool_calls) []))
    (trace @{:kind :model :step steps :ms (ms-since t0)
             :finish-reason (llm/reply-finish-reason res)
             :tool-calls (length calls) :usage (get res :usage)})
    (if (empty? calls)
      (do (set text (get msg :content)) (set stopped :done) (break))
      (run-tools! agent steps calls)))
  (mem/trim! m)
  (trace @{:kind :done :steps steps :stopped-by stopped :usage (agent :usage)})
  @{:text text :steps steps :stopped-by stopped
    :usage (agent :usage) :run-usage run-usage :messages (mem/messages m)})
