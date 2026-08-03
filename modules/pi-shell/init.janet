# pi-shell —— 把「非互動 agent CLI」包成子行程的**薄透傳殼**（門面）。
#
# 原本只包 `pi`，後來發現 `claude -p` 是**完全同一種形狀**（非互動、吃 prompt、自帶工具、
# 用 stdin 餵料），所以核心泛化成 run-agent，pi 與 claude 各是一個便利包裝。
# 目錄名維持 pi-shell（沿用原本的命名），但它不再只服務 pi。
#
# ── 拆檔 ────────────────────────────────────────────────────────────
#   proc.janet  子行程管線（os/spawn ／讀寫分 fiber ／proc-wait），不認識任何 agent
#   init.janet  本檔：agent 的知識（指令名、旗標形狀）＋門面
#   main.janet  CLI 進入點
#
# ── 跟 llm-http 怎麼分工 ────────────────────────────────────────────
#   要**自己的多輪 tool loop**、要**圖像輸入**、要 OpenAI 相容的 messages[] →  llm-http
#   要**現成就能用的 agent**、不介意它自帶工具與 agent 行為、單次問答      →  本模組
#
#   ⚠ `claude -p` 是 **agent 不是 chat completion 端點**：沒有 messages[] 可控、
#     自帶 bash/edit/write 與自己的 system prompt，所以跑不了呼叫端自己的 tool loop。
#     而且每次呼叫都重送整份 Claude Code system prompt，實測一句「只回兩個字」約 $0.016，
#     當一般 chat 後端很浪費。要拿 Claude 當**裸模型**請走 llm-http 的 claude endpoint。
#
# ⚠ 這是**薄透傳**：刻意不幫呼叫端偷加 --no-tools／--disallowedTools 之類的限制。
#   pi 與 claude 預設都帶 bash/edit/write，會真的動你的檔案。要不要縮限是呼叫端的決定
#   ——也就是說，自己在測的時候請務必自己加上限制旗標。

(import spork/json)
(import ./proc :prefix "" :export true)

(def pi-cmd     "pi 的執行檔名，走 PATH 找。" "pi")
(def claude-cmd "Claude Code CLI 的執行檔名，走 PATH 找。" "claude")

(def default-claude-model
  "run-claude 沒指定 model 時就讓 claude 自己用它的預設，不硬塞。
  這裡列一顆便宜的給測試／實驗用。"
  "claude-haiku-4-5-20251001")

(def claude-models
  "Claude 家族的 model id，換一顆時參考。"
  ["claude-opus-4-8" "claude-sonnet-5" "claude-haiku-4-5" "claude-fable-5"])

(defn run-agent
  ``跑一次非互動 agent CLI，回 @{:out "它的 stdout" :code 退出碼}。

  cmd       —— 執行檔名（"pi"／"claude"／任何同形狀的東西）
  args      —— 原樣接在 `<cmd> -p` 後面的參數陣列
  stdin-str —— 可省略；有給就整段餵進它的 stdin

  `-p` 是 pi 與 claude 共通的「非互動、印完就走」旗標，所以由本函式墊上；
  除此之外一律原樣透傳。``
  [cmd args &opt stdin-str]
  (run (array/concat @[cmd "-p"] (or args @[])) stdin-str))

(defn run-pi
  ``跑一次 `pi -p <args...>`。⚠ 不加任何限制旗標，要縮限請自己在 args 裡放 --no-tools。``
  [args &opt stdin-str]
  (run-agent pi-cmd args stdin-str))

(defn run-claude
  ``跑一次 `claude -p <args...>`。

  model 有給就把 ["--model" <model>] 墊到 args 前面；省略就讓 claude 用它自己的預設。
  ⚠ 不加任何限制旗標，要縮限請自己在 args 裡放 --disallowedTools／--allowedTools。
  ⚠ claude CLI 走的是**已登入的 OAuth**，不需要 ANTHROPIC_API_KEY；但每次呼叫都是真金白銀。``
  [args &opt stdin-str model]
  (def full (if model
              (array/concat @["--model" model] (or args @[]))
              (array ;(or args @[]))))
  (run-agent claude-cmd full stdin-str))

(defn run-claude-json
  ``同 run-claude，但強制 `--output-format json` 並把信封解開。

  回 @{:ok 成功? :text 答案字串 :code 退出碼 :envelope 整份解好的 JSON :raw 原始 stdout}。
  信封裡有 :is_error :result :session_id :usage :total_cost_usd 等欄位，
  想看花了多少錢就看 (get-in r [:envelope :total_cost_usd])。``
  [args &opt stdin-str model]
  (def r (run-claude (array/concat @["--output-format" "json"] (or args @[]))
                     stdin-str model))
  (def [ok env] (protect (json/decode (r :out) true)))
  (if (and ok (dictionary? env))
    @{:ok       (and (= 0 (r :code)) (not (get env :is_error)))
      :text     (get env :result)
      :code     (r :code)
      :envelope env
      :raw      (r :out)}
    @{:ok false :text nil :code (r :code) :envelope nil :raw (r :out)}))

(defn pi-available?     "PATH 上有沒有 pi。"     [] (available? pi-cmd))
(defn claude-available? "PATH 上有沒有 claude。" [] (available? claude-cmd))
