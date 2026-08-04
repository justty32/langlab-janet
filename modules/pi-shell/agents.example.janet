# pi-shell 的 agent 設定檔**範本**。
#
# ⚠ 這個檔案是**資料不是程式**：內容只會被 parse（`parse-all`），**不會被 eval**。
#   不要寫 (def …)／(import …)／(os/getenv …)，寫了也只是一串沒人執行的 tuple。
#
# ── 放哪裡 ──────────────────────────────────────────────────────────
#   複製一份到下列任一位置，模組 import 時會自動載入（找不到就靜靜跳過）：
#
#     ① $PI_SHELL_AGENTS 指的檔案                ← 優先序最高
#     ② $XDG_CONFIG_HOME/pi-shell/agents.janet
#     ③ ~/.config/pi-shell/agents.janet
#
#   也可以明確指定：
#     程式裡： (agent/load-agents! "/路徑/agents.janet")
#     CLI：    ./build/pi-shell --agent-file /路徑/agents.janet --agent 我的名字 "嗨"
#              （--agent-file／--agent 只認**第一個參數位置**，見 cli.janet 的說明）
#
# ── 格式 ────────────────────────────────────────────────────────────
#   最外層一張表：`"agent 名字" {設定}`。檔案裡可以有多張表，會依序疊加。
#
#   一份設定認得的欄位（只有 :cmd 必填）：
#
#     :cmd           執行檔名，走 PATH 找                      ← **必填**
#     :prompt-flag   非互動旗標，預設 "-p"；寫 false 表示這支不用墊
#     :model-flag    指定 model 的旗標（例如 "--model"／"-m"）；沒有就表示不吃 model
#     :default-model 沒指定 model 時墊哪一顆；不寫＝讓那支 CLI 用它自己的預設
#     :note          一句話說明，會出現在 --list-agents
#
#   ⚠ 本殼是**薄透傳**：設定裡刻意**不能**放 --no-tools／--disallowedTools 這類限制旗標。
#     要縮限請每次在呼叫端自己加——「要不要讓 agent 動你的檔案」不該被一份設定檔決定。

{# ── ① 一支跟 pi／claude 同形狀的 CLI ────────────────────────────────
 "qwen-cli"
 {:cmd        "qwen"
  :model-flag "-m"
  :note       "本機 qwen CLI，`qwen -p <prompt>`。"}

 # ── ② 非互動旗標不是 -p 的 ──────────────────────────────────────────
 "aider"
 {:cmd         "aider"
  :prompt-flag "--message"
  :note        "aider 的非互動旗標是 --message 不是 -p。"}

 # ── ③ 根本不用非互動旗標的（prompt 直接當位置參數）──────────────────
 "echo-agent"
 {:cmd         "echo"
  :prompt-flag false
  :note        "拿 echo 當假 agent，測管線用；不墊任何旗標。"}

 # ── ④ 固定用某一顆 model 的 claude ─────────────────────────────────
 # ⚠ claude 每次呼叫都是真金白銀，固定一顆便宜的可以省不少。
 "claude-cheap"
 {:cmd           "claude"
  :model-flag    "--model"
  :default-model "claude-haiku-4-5-20251001"
  :note          "固定跑便宜的 haiku。⚠ 仍然預設帶 bash/edit/write，要縮限自己加旗標。"}}
