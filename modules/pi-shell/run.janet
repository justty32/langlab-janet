# 跑 agent 這一層 —— 把 registry 的「形狀知識」組成一條指令，交給 proc.janet 去 spawn。
#
#   proc.janet    子行程管線，不認識任何 agent
#   agents.janet  agent 有哪些、旗標長什麼形狀（registry）
#   run.janet     本檔：把兩者接起來，加上 pi／claude 的便利包裝
#
# ⚠ 這是**薄透傳**：刻意不幫呼叫端偷加 --no-tools／--disallowedTools 之類的限制。
#   pi 與 claude 預設都帶 bash/edit/write，會真的動你的檔案。要不要縮限是呼叫端的決定
#   ——也就是說，自己在測的時候請務必自己加上限制旗標。

(import spork/json)
(import ./proc)
(import ./agents :as ag)

(defn agent-argv
  ``把「agent ＋ 參數」組成完整的指令陣列（不執行，方便測與 debug）。

  順序：<cmd> <prompt-flag> [<model-flag> <model>] <args...>
  model 省略時用 spec 的 :default-model；兩邊都沒有就不墊 model 旗標。``
  [what args &opt model]
  (def spec (ag/agent-spec what))
  (def argv @[(spec :cmd)])
  (when (spec :prompt-flag) (array/push argv (spec :prompt-flag)))
  (def m (or model (spec :default-model)))
  (when (and m (spec :model-flag))
    (array/push argv (spec :model-flag) m))
  (array/concat argv (or args @[]))
  argv)

(defn run-agent
  ``跑一次非互動 agent CLI，回 @{:out "它的 stdout" :code 退出碼}。

  what      —— registry 裡的名字（"pi"／"claude"／你自己註冊的），
               或直接給執行檔名（不在 registry 裡就當成執行檔名，維持舊行為），
               或直接給一張設定 table（inline agent，不必註冊）
  args      —— 原樣接在 `<cmd> -p` 後面的參數陣列
  stdin-str —— 可省略；有給就整段餵進它的 stdin
  model     —— 可省略；有給且這支 agent 有 :model-flag 才會墊上去

  `-p` 是 pi 與 claude 共通的「非互動、印完就走」旗標，由 registry 的
  :prompt-flag 決定（預設就是 "-p"）；除此之外一律原樣透傳。``
  [what args &opt stdin-str model]
  (proc/run (agent-argv what args model) stdin-str))

(defn run-pi
  ``跑一次 `pi -p <args...>`。⚠ 不加任何限制旗標，要縮限請自己在 args 裡放 --no-tools。``
  [args &opt stdin-str]
  (run-agent "pi" args stdin-str))

(defn run-claude
  ``跑一次 `claude -p <args...>`。

  model 有給就把 ["--model" <model>] 墊到 args 前面；省略就讓 claude 用它自己的預設。
  ⚠ 不加任何限制旗標，要縮限請自己在 args 裡放 --disallowedTools／--allowedTools。
  ⚠ claude CLI 走的是**已登入的 OAuth**，不需要 ANTHROPIC_API_KEY；但每次呼叫都是真金白銀。``
  [args &opt stdin-str model]
  (run-agent "claude" args stdin-str model))

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

(defn agent-available?
  "這支 agent 的執行檔在不在 PATH 上（用 `<cmd> --version` 探測）。"
  [what]
  (proc/available? ((ag/agent-spec what) :cmd)))

(defn pi-available?     "PATH 上有沒有 pi。"     [] (agent-available? "pi"))
(defn claude-available? "PATH 上有沒有 claude。" [] (agent-available? "claude"))
