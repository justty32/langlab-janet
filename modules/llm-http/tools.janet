# tool loop —— 這個模組的重點。
#
# 一輪完整的 tool use 長這樣（實測跑通的流程，四步）：
#   1. 送 {:model … :messages [...] :tools [...]}，tools 是 OpenAI 格式
#   2. 回應若有 (get-in r [:choices 0 :message :tool_calls])
#      → 把**整則 assistant message 原樣 push 回 messages**（不能只留 content，
#        tool_calls 那段是後面 role:"tool" 訊息的錨點，拿掉就對不起來）
#   3. 每個 call：解 :function :arguments（那是一段 **JSON 字串**，要再 decode 一次）
#      → 在本地執行 → push @{:role "tool" :tool_call_id … :content 結果字串}
#   4. 再送一次，模型拿工具結果作答
#
# with-tools 就是把這四步包成一個會自己轉圈的迴圈，直到模型不再要求工具為止，
# 並且有 max-rounds 上限防呆（模型鬼打牆一直叫工具時不會無限打下去）。

(import spork/json)
(import ./client)

(defn tool-spec
  ``組一個 OpenAI 格式的 tool 宣告。

  (tool-spec "get_weather" "查詢城市目前天氣"
             {:type "object"
              :properties {:city {:type "string"}}
              :required ["city"]})

  parameters 就是一份 JSON schema，直接用 Janet 的 struct／table 寫，encode 時會變 JSON。``
  [name description parameters]
  {:type "function"
   :function {:name name :description description :parameters parameters}})

(defn- stringify
  "工具的回傳值要以字串送回模型：字串原樣，其他東西 encode 成 JSON。"
  [v]
  (cond
    (string? v) v
    (buffer? v) (string v)
    (nil? v)    ""
    (string (json/encode v))))

(defn- decode-args
  "把 :function :arguments 那段 JSON 字串解成 table；解不出來就給空 table。"
  [raw]
  (if (or (nil? raw) (empty? raw))
    @{}
    (let [[ok v] (protect (json/decode raw true))]
      (if (and ok (dictionary? v)) v @{}))))

(defn- invoke
  ``執行單一個工具。★ 用 protect 包住：handler 自己炸掉時要把錯誤**當成工具結果送回模型**，
  而不是讓整條 loop 掛掉——模型通常能看懂錯誤訊息並改用別的參數重試。``
  [handlers name args]
  (def h (get handlers name))
  (if (nil? h)
    (string "錯誤：沒有名為 " name " 的工具")
    (let [[ok v] (protect (h args))]
      (if ok (stringify v) (string "工具執行失敗：" v)))))

(defn with-tools
  ``跑完整的多輪 tool loop，直到模型不再要求工具（或撞到 max-rounds）。

  cfg      —— endpoint 設定（endpoints/endpoint 給的那份）
  messages —— 起始訊息陣列；**不會被就地改動**，內部自己複製一份
  tools    —— OpenAI 格式的 tool 宣告陣列（用 tool-spec 組）
  handlers —— 「工具名 → Janet 函式」的表；函式收一張解好的參數 table，
              回傳字串（或任何東西，非字串會被 encode 成 JSON）

  具名參數：
    :system     可省略的 system 訊息，會被插到歷史**最前面**（跟 client/ask 的
                第三個參數對齊，省得自己組 @{:role "system" …}）。
                ⚠ 若 messages 第一則本來就是 system，這個參數會被忽略——避免
                一次送出兩則 system 讓模型無所適從。要換掉原本那則就自己改 messages。
    :max-rounds 最多打幾次模型，預設 8（防無限迴圈）
    :trace      可省略的回呼 (fn [name args result])，每執行一個工具就叫一次，
                方便 CLI 印出「模型要求 X → 本地執行 → 結果」

  回傳 @{:text 最終答案字串（撞上限時是 nil）
         :messages 完整的訊息歷史（含 assistant 的 tool_calls 與 role:"tool" 的結果）
         :rounds 實際打了幾輪
         :exhausted 是不是撞到 max-rounds 才停的}``
  [cfg messages tools handlers &named system max-rounds trace]
  (default max-rounds 8)
  (def history (array ;messages))       # 複製一份，不動呼叫端的陣列

  # system 是「便利參數」：只在呼叫端沒自己放 system 時才插進去
  (when (and system (not (empty? system))
             (not= "system" (get (get history 0) :role)))
    (array/insert history 0 @{:role "system" :content system}))
  (var rounds 0)
  (var final nil)
  (var exhausted false)

  (while true
    (when (>= rounds max-rounds)
      (set exhausted true)
      (break))
    (++ rounds)

    (def res (client/chat cfg history :tools tools))
    (def msg (client/reply-message res))
    (unless msg
      (error (string "回應裡沒有 message：" (string/format "%q" res))))

    # ★ 整則原樣接回歷史（含 tool_calls）
    (array/push history msg)

    (def calls (get msg :tool_calls))
    (if (or (nil? calls) (empty? calls))
      (do (set final (get msg :content)) (break))
      (each c calls
        (def name   (get-in c [:function :name]))
        (def args   (decode-args (get-in c [:function :arguments])))
        (def result (invoke handlers name args))
        (when trace (trace name args result))
        (array/push history @{:role         "tool"
                              :tool_call_id (get c :id)
                              :content      result}))))

  @{:text final :messages history :rounds rounds :exhausted exhausted})

# ── 內建示範工具 ─────────────────────────────────────────────────────
# 純粹讓 CLI 的 --tools 有東西可跑、也讓測試有個不碰外界的靶。
# ★ 刻意都是無害的：只讀本行程的時鐘、回假天氣，不碰檔案、不執行指令。

(defn- tool-now [_]
  # ⚠ os/date 的 :month／:month-day 是 **0 起算**的，要 +1 才是人看的月份／日期
  (def d (os/date (os/time) true))
  (string/format "%04d-%02d-%02dT%02d:%02d:%02dZ"
                 (d :year) (inc (d :month)) (inc (d :month-day))
                 (d :hours) (d :minutes) (d :seconds)))

(defn- tool-weather [args]
  {:city (get args :city "?") :temp_c 31 :cond "晴時多雲"})

(def demo-tools
  "示範用的 tool 宣告陣列，配 demo-handlers 一起用。"
  [(tool-spec "now" "取得目前的 UTC 時間"
              {:type "object" :properties {} :required []})
   (tool-spec "get_weather" "查詢某座城市目前的天氣（示範用的假資料）"
              {:type "object"
               :properties {:city {:type "string" :description "城市名稱"}}
               :required ["city"]})])

(def demo-handlers
  "示範用的 handler 表：工具名 → Janet 函式。"
  {"now" tool-now "get_weather" tool-weather})
