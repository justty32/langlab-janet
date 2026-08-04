# agent 設定檔的載入 —— 讓使用者把自己的 `<cmd> -p <args>` 形狀 CLI 加進來，
# 不必改 repo、也不必把自己的設定 commit 進來。
#
# ★ 只 **parse** 不 **eval**：檔案內容是一份 Janet **資料字面值**（用 parse-all 讀），
#   不會被當程式執行。範本見同目錄的 agents.example.janet。
#
# ── 檔案長怎樣 ──────────────────────────────────────────────────────
#     {"qwen-cli" {:cmd "qwen" :model-flag "-m" :note "本機 qwen CLI"}}
#
#   最外層一張表：名字 → 設定；檔案裡可以有多張，依序疊加。
#
# ── 自動探測順序 ────────────────────────────────────────────────────
#   ① 環境變數 PI_SHELL_AGENTS 指的檔案
#   ② $XDG_CONFIG_HOME/pi-shell/agents.janet
#   ③ ~/.config/pi-shell/agents.janet
#   **找不到就靜靜跳過**（沒有設定檔是正常狀態）；找到了但壞掉會在 stderr 印一行中文警告。
#
# （跟 llm-http/config.janet 是同一套做法，刻意沒有共用程式碼：
#   兩個模組各自獨立、各自能單獨 import，不互相依賴。）

(import ./agents :as ag)

(def loaded-files
  "這個行程裡成功載入過的設定檔路徑（依載入順序）。"
  @[])

(defn- fail
  [fmt & args]
  (error (string/format fmt ;args)))

(defn parse-agents
  ``把一段設定檔文字解成「名字 → 設定」的表；**只 parse 不 eval**。
  label 只用在錯誤訊息裡（通常給檔名）。``
  [text &opt label]
  (default label "（字串）")
  (def [ok forms] (protect (parse-all text)))
  (unless ok
    (fail (string "agent 設定檔 %s 格式有誤，不是合法的 Janet 資料字面值：%s\n"
                  "提示：內容應該是一張表，像 {\"名字\" {:cmd \"…\"}}；括號有沒有少收一個？")
          label forms))
  (when (empty? forms)
    (fail "agent 設定檔 %s 是空的（至少要有一張 {\"名字\" {:cmd \"…\"}} 的表）" label))
  (def out @{})
  (each form forms
    (unless (dictionary? form)
      (fail (string "agent 設定檔 %s 的最外層應該是一張表（名字 → 設定），收到的是 %s\n"
                    "提示：這個檔案是**資料**不是程式，不要寫 (def …)／(import …)。")
            label (type form)))
    (eachp [k spec] form
      (put out (if (bytes? k) (string k) (string/format "%s" k)) spec)))
  out)

(defn load-agents!
  ``從設定檔把使用者的 agent 讀進 registry，回傳載入的名字陣列（排序過）。

  ⚠ 這是**明確要求**載入的入口，所以檔案不存在／格式壞／設定不合法一律丟中文錯誤。
  想要「有就載、沒有就算了」請用 autoload-agents!。``
  [path]
  (def p (string path))
  (unless (os/stat p :mode)
    (fail "找不到 agent 設定檔：%s" p))
  (def [ok content] (protect (slurp p)))
  (unless ok (fail "讀不到 agent 設定檔 %s：%s" p content))

  (def entries (parse-agents (string content) p))
  (def names @[])
  (eachp [name spec] entries
    (def [ok2 e] (protect (ag/define-agent name spec p)))
    (unless ok2
      (fail "agent 設定檔 %s 裡的「%s」設定有問題：\n  %s" p name e))
    (array/push names (string name)))
  (unless (index-of p loaded-files) (array/push loaded-files p))
  (sorted names))

(defn config-candidates
  "自動探測會依序看的路徑（只回位置，不管檔案在不在）。"
  []
  (def out @[])
  (def push-env
    (fn [var suffix]
      (when-let [v (os/getenv var)]
        (unless (empty? v)
          (array/push out (if suffix (string v suffix) v))))))
  (push-env "PI_SHELL_AGENTS" nil)
  (push-env "XDG_CONFIG_HOME" "/pi-shell/agents.janet")
  (push-env "HOME" "/.config/pi-shell/agents.janet")
  out)

(defn autoload-agents!
  ``自動探測並載入第一份找得到的設定檔；回傳它的路徑，都找不到就回 nil。

  ★ 沒有設定檔是**正常狀態**，這裡絕不報錯、也不印任何東西。
  ★ 找到了但壞掉會在 stderr 印一行中文警告，然後當作沒載入。``
  []
  (var hit nil)
  (each path (config-candidates)
    (when (and (nil? hit) (os/stat path :mode))
      (def [ok e] (protect (load-agents! path)))
      (if ok
        (set hit path)
        (eprintf "⚠ agent 設定檔載入失敗，已略過：%s" e))))
  hit)
