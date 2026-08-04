# agent registry —— 「有哪些 agent CLI」這一件事：內建資料 ＋ 註冊／查詢。
#
# 這一層是**知識**不是行為：只有一張表。真的去 spawn 的是 run.janet，
# 管線細節在 proc.janet（那一層完全不知道 agent 是什麼）；
# 一份設定合不合法由 spec.janet 判（純函式，欄位說明也在那）。
#
# ── 為什麼會有 registry ─────────────────────────────────────────────
#   `pi -p <args>` 與 `claude -p <args>` 是**完全同一種形狀**：非互動、吃 prompt、
#   自帶工具、用 stdin 餵料。既然形狀一樣，那就不該把「有哪兩支」寫死在程式裡——
#   使用者手上任何 `<cmd> -p <args>` 形狀的 CLI 都應該能加進來。
#   （跟 llm-http 的 endpoint registry 是同一個設計思想。）

(import ./spec :as sp)

(def pi-cmd     "pi 的執行檔名，走 PATH 找。" "pi")
(def claude-cmd "Claude Code CLI 的執行檔名，走 PATH 找。" "claude")

(def default-claude-model
  "run-claude 沒指定 model 時就讓 claude 自己用它的預設，不硬塞。
  這裡列一顆便宜的給測試／實驗用。"
  "claude-haiku-4-5-20251001")

(def claude-models
  "Claude 家族的 model id，換一顆時參考。"
  ["claude-opus-4-8" "claude-sonnet-5" "claude-haiku-4-5" "claude-fable-5"])

(def builtin-agents
  "兩支內建 agent 的**純資料**。使用者自己的不要寫進這裡，走 define-agent／設定檔。"
  {"pi"
   {:cmd         pi-cmd
    :prompt-flag "-p"
    :model-flag  "--model"
    :note        "pi。⚠ 預設帶工具，要縮限請自己在 args 裡放 --no-tools。"}

   "claude"
   {:cmd         claude-cmd
    :prompt-flag "-p"
    :model-flag  "--model"
    :note        (string "Claude Code CLI，走已登入的 OAuth（不需要 ANTHROPIC_API_KEY）。"
                         "⚠ 每次呼叫都是真金白銀，實測一句約 $0.016；"
                         "⚠ 預設帶 bash/edit/write，要縮限請自己放 --disallowedTools。")}})

(def agent-specs
  ``活的 agent registry：名字 → 設定。內建兩筆先在裡面。
  讀法就是一般的表操作：(get agent-specs "pi")、(keys agent-specs)。``
  (table ;(kvs builtin-agents)))

(def agent-sources
  "名字 → 這筆打哪來：:builtin／:runtime／設定檔路徑字串。"
  (table ;(mapcat |[$ :builtin] (keys builtin-agents))))

(defn define-agent
  ``註冊（或覆蓋）一個有名字的 agent，回傳驗證＋正規化之後的設定。

    (define-agent "qwen-cli" {:cmd "qwen" :prompt-flag "-p" :model-flag "-m"})
    (run-agent "qwen-cli" ["回 ok"])

  source 是「這筆打哪來」的標記，給 --list-agents 顯示用。``
  [name spec &opt source]
  (default source :runtime)
  (def key (string name))
  (def clean (sp/normalize-spec spec key))
  (put agent-specs key clean)
  (put agent-sources key source)
  clean)

(defn undefine-agent!
  "把一個 agent 從 registry 拿掉。回傳有沒有真的拿掉東西。"
  [name]
  (def key (string name))
  (def had (truthy? (get agent-specs key)))
  (put agent-specs key nil)
  (put agent-sources key nil)
  had)

(defn reset-agents!
  "把 registry 打回「只剩內建兩筆」的狀態。測試與 REPL 裡很好用。"
  []
  (each k (keys agent-specs) (put agent-specs k nil) (put agent-sources k nil))
  (eachp [k v] builtin-agents
    (put agent-specs k v)
    (put agent-sources k :builtin))
  agent-specs)

(defn agent-names
  "registry 裡所有 agent 的名字（排序過）。"
  []
  (sorted (keys agent-specs)))

(defn builtin-agent?
  "這個名字是不是內建的。"
  [name]
  (= :builtin (get agent-sources (string name))))

(defn agent-source
  "這個 agent 打哪來：:builtin／:runtime／設定檔路徑字串；沒這個名字回 nil。"
  [name]
  (get agent-sources (string name)))

(defn agent-spec
  ``把「名字字串／設定 table」解析成一份可用的 agent 設定。

  ① 名字在 registry 裡 → 那一筆
  ② 名字不在 registry  → 當成**執行檔名**直接用（維持舊行為：run-agent 一直都吃 cmd）
  ③ 給的是 table／struct → 當場驗證後直接用（inline agent，不必註冊）``
  [what]
  (cond
    (bytes? what)
    (or (get agent-specs (string what))
        (sp/normalize-spec {:cmd (string what)} (string what)))

    (dictionary? what)
    (sp/normalize-spec what (or (get what :name) "（inline）"))

    (error (string/format
             "agent 的第一個參數要嘛是名字／執行檔名字串、要嘛是一張設定 table，收到的是 %s"
             (type what)))))
