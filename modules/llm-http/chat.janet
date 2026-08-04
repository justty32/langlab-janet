# 對話層 —— 把「messages ＋ 參數」組成 payload，交給傳輸層送出，再把答案挖出來。
#
# 傳輸（HTTP／JSON、連不上怎麼報錯）在 transport.janet；這一層只管**語意**：
# 哪些參數要怎麼合併、答案在回應的哪個位置、ask 這種一行式的便利包裝。
#
# ── 請求參數的合併優先序（低 → 高，後面的蓋前面的）─────────────────
#   ① endpoint 自己的 :params        （(endpoint {:model … :params {:temperature 0.2}})）
#   ② chat 的 :params 具名參數        （這次呼叫整批帶的參數）
#   ③ chat 的 :temperature/:max-tokens/:top-p 具名參數
#   ④ chat 的 :extra                  （原樣併進 payload，什麼都蓋得掉）
#
#   :model 與 :messages 永遠由 cfg／呼叫端決定，不受 :params 影響
#   ——想換 model 請走 (endpoint "local" {:model "qwen"})，別塞進 :params。

(import ./transport :as tp)
(import ./media)

# payload 用的是 OpenAI 的 snake_case 欄位名；Janet 這邊的具名參數習慣用 kebab-case，
# 這張表就是兩者的對照（只列本模組有具名參數的那幾個）。
(def param-aliases
  "具名參數 → payload 欄位名。"
  {:temperature :temperature
   :max-tokens  :max_tokens
   :top-p       :top_p})

(defn- merge-into!
  "把一張表原樣併進 payload（nil 直接跳過）。"
  [payload t]
  (when t (eachp [k v] t (put payload k v)))
  payload)

(defn build-payload
  ``組出要 POST 的 payload table。抽出來是為了**離線就能驗合併優先序**（見 test/）。

  參數與合併順序見本檔開頭那段說明。``
  [cfg messages &named tools tool-choice temperature max-tokens top-p extra params]
  (unless (cfg :model)
    (error "這份 endpoint 設定缺 :model —— chat 不知道要跟哪個模型講話"))
  (def payload @{:model (cfg :model) :messages messages})
  (merge-into! payload (cfg :params))       # ① endpoint 的預設參數
  (merge-into! payload params)              # ② 這次呼叫整批帶的
  # ③ 具名參數（給了才算，nil 表示「不表態」，不會把前面的蓋掉）
  (unless (nil? temperature) (put payload :temperature temperature))
  (unless (nil? max-tokens)  (put payload :max_tokens  max-tokens))
  (unless (nil? top-p)       (put payload :top_p       top-p))
  (when tools       (put payload :tools tools))
  (when tool-choice (put payload :tool_choice tool-choice))
  (merge-into! payload extra)               # ④ 原樣併入，優先序最高
  payload)

(defn chat
  ``打一次 chat completion。messages 是 OpenAI 格式的訊息陣列，回傳整份解好的回應。

  具名參數（都可省略）：
    :tools       OpenAI 格式的 tool 宣告陣列
    :tool-choice "auto"／"none"／指定某個 tool
    :temperature :max-tokens :top-p
    :params      一整張參數表（key 用 payload 的原名，例如 :max_tokens、:seed）
    :extra       一張表，原樣併進 payload，**優先序最高**

  合併優先序：endpoint 的 :params ＜ :params ＜ 具名參數 ＜ :extra。

  ⚠ OpenRouter 那條線特別注意：不同模型的 supported_parameters 不一樣，
    送了它不支援的參數（response_format／top_p／seed…）**不會報錯，就是被無視**，
    你會拿到 exit 0 加一份看起來像答案的東西。要確認只能看回應內容對不對。``
  [cfg messages &named tools tool-choice temperature max-tokens top-p extra params]
  (tp/post-chat cfg (build-payload cfg messages
                                   :tools tools :tool-choice tool-choice
                                   :temperature temperature :max-tokens max-tokens
                                   :top-p top-p :extra extra :params params)))

(defn reply-message
  "從回應取出 assistant 那則訊息（含 :content 與可能的 :tool_calls）；取不到回 nil。"
  [res]
  (get-in res [:choices 0 :message]))

(defn reply-text
  "從回應取出答案文字；取不到回 nil（例如模型只回了 tool_calls）。"
  [res]
  (get-in res [:choices 0 :message :content]))

(defn reply-finish-reason
  ``模型為什麼停下來："stop"（講完了）／"length"（撞到 max_tokens）／
  "tool_calls"（要叫工具）…取不到回 nil。

  ⚠ 值得養成看它的習慣：**答案被截斷時 HTTP 仍然是 200**，只有這個欄位講得出來。``
  [res]
  (get-in res [:choices 0 :finish_reason]))

(defn truncated?
  "這次回應是不是因為撞到 max_tokens 被截斷的。"
  [res]
  (= "length" (reply-finish-reason res)))

(defn ask
  ``最常用的一行式問答：給 prompt，拿字串答案回來。

  system —— 可省略的 system 訊息。
  images —— 可省略的圖檔路徑／URL 陣列；有給就自動把 user 訊息換成 parts 形狀。
            ⚠ 記得挑吃圖的 endpoint（見 endpoint 設定的 :vision?）。

  再後面的具名參數原樣轉給 chat（:temperature／:max-tokens／:top-p／:params／:extra），
  所以 (ask cfg "…" nil nil :temperature 0) 這種寫法是可以的。``
  [cfg prompt &opt system images &named temperature max-tokens top-p extra params]
  (def messages @[])
  (when (and system (not (empty? system)))
    (array/push messages @{:role "system" :content system}))
  (array/push messages (media/user-message prompt images))
  (def res (chat cfg messages
                 :temperature temperature :max-tokens max-tokens :top-p top-p
                 :extra extra :params params))
  (def text (reply-text res))
  (unless (string? text)
    (error (string "回應裡取不出答案文字：" (string/format "%q" res))))

  # ★ 實測踩到的坑：max_tokens 太小時，**推理模型會把預算全花在 reasoning_tokens 上**，
  #   content 回一個空字串、HTTP 仍然是 200。ask 承諾回答案，這種情況直接講清楚，
  #   不要讓呼叫端拿到 "" 還以為模型真的沒話說。
  (when (and (empty? text) (truncated? res))
    # ⚠ string/format 只吃**一個** format 字串，多段要先用 string 接起來
    (error (string/format
             (string "答案被 max_tokens 截斷了（finish_reason=length），content 是空字串。\n"
                     "推理模型會先花掉 reasoning tokens，預算太小就什麼都印不出來——把 max_tokens 調大。\n"
                     "這次用量：%q")
             (get res :usage))))
  text)
