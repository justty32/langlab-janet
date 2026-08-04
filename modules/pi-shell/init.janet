# pi-shell —— 把「非互動 agent CLI」包成子行程的**薄透傳殼**（門面）。
#
# 原本只包 `pi`，後來發現 `claude -p` 是**完全同一種形狀**（非互動、吃 prompt、自帶工具、
# 用 stdin 餵料），所以核心泛化成 run-agent；再後來把「有哪些 agent」也做成 registry，
# 使用者手上任何 `<cmd> -p <args>` 形狀的 CLI 都能自己加進來。
# 目錄名維持 pi-shell（沿用原本的命名），但它不只服務 pi。
#
# ── 拆檔 ────────────────────────────────────────────────────────────
#   proc.janet    子行程管線（os/spawn／drain／run／available?），**不認識任何 agent**
#   agents.janet  agent registry：內建 pi／claude 的旗標形狀 ＋ define-agent ＋ 驗證
#   config.janet  agent 設定檔載入（load-agents!／autoload-agents!，只 parse 不 eval）
#   run.janet     把 registry 組成指令交給 proc：run-agent／run-pi／run-claude／…
#   cli.janet     CLI 的參數處理（哪些旗標本殼要吃掉、哪些原樣透傳）
#   init.janet    本檔：門面，把上面幾支 re-export 出來
#   main.janet    CLI 進入點
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
#
# ★ import 這支的**副作用**：會自動探測一次使用者的 agent 設定檔
#   （PI_SHELL_AGENTS → $XDG_CONFIG_HOME/pi-shell/agents.janet
#     → ~/.config/pi-shell/agents.janet）。沒有設定檔是正常狀態，不會有任何輸出。

(import ./proc   :prefix "" :export true)
(import ./spec   :prefix "" :export true)
(import ./agents :prefix "" :export true)
(import ./config :prefix "" :export true)
(import ./run    :prefix "" :export true)

# ★ 副作用只有這一行：有設定檔就載進 registry，沒有就當沒事發生。
(autoload-agents!)
