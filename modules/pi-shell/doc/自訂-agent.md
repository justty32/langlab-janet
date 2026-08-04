# 自訂 agent

[← 回 pi-shell README](../README.md)


「非互動 agent CLI」是一種**形狀**不是兩支特定程式，所以內建的 `pi`／`claude`
只是 registry 裡的兩筆。你自己的 CLI 也能加進來
（跟 [`../llm-http/`](../../llm-http/doc/自訂-endpoint.md) 的 endpoint registry 是同一個設計思想）。

## 一份 agent 設定認得的欄位

只有 `:cmd` 必填。**欄位名打錯會被擋下來並列出可用欄位。**

| 欄位 | 意思 |
|------|------|
| `:cmd` | **必填**。執行檔名，走 PATH 找 |
| `:prompt-flag` | 非互動旗標，**預設 `"-p"`**；寫 `false` 表示這支不用墊任何旗標 |
| `:model-flag` | 指定 model 的旗標（`"--model"`／`"-m"`）；沒有就表示這支不吃 model |
| `:default-model` | 沒指定 model 時墊哪一顆；不寫＝讓那支 CLI 用它自己的預設 |
| `:note` | 一句話說明，會出現在 `--list-agents` |

組出來的指令長這樣：`<cmd> <prompt-flag> [<model-flag> <model>] <args...>`。

## 三條路

```janet
# ① inline table：完全不註冊
(agent/run-agent {:cmd "my-agent" :prompt-flag "--ask"} ["回 ok"])

# ② define-agent：註冊成有名字的
(agent/define-agent "qwen-cli" {:cmd "qwen" :model-flag "-m" :note "本機 qwen CLI"})
(agent/run-agent "qwen-cli" ["回 ok"])
(agent/agent-names)          # → @["claude" "pi" "qwen-cli"]
(agent/agent-source "qwen-cli")   # → :runtime
(agent/undefine-agent! "qwen-cli")
(agent/reset-agents!)        # 打回「只剩內建兩筆」

# ③ 設定檔：不必改 repo、也不必 commit 自己的設定
(agent/load-agents! "/路徑/agents.janet")
```

**設定檔範本（含中文註解）：[`agents.example.janet`](../agents.example.janet)** —— 複製一份去改。
放到下列任一位置，`import` 這個模組時就會**自動載入**（依序找，第一個找到的贏）：

1. 環境變數 `PI_SHELL_AGENTS` 指的檔案
2. `$XDG_CONFIG_HOME/pi-shell/agents.janet`
3. `~/.config/pi-shell/agents.janet`

```janet
{"qwen-cli"   {:cmd "qwen" :model-flag "-m"}
 "aider"      {:cmd "aider" :prompt-flag "--message"}      # 非互動旗標不是 -p
 "echo-agent" {:cmd "echo" :prompt-flag false}}            # 根本不墊旗標
```

- **只 parse 不 eval**（跟 llm-http 的設定檔同一套做法）。
- **沒有設定檔是正常狀態**：找不到就靜靜跳過；找到了但壞掉會在 stderr 印一行中文警告。
- 明確呼叫的 `load-agents!` 則相反：檔案不存在／格式壞／設定不合法一律丟中文錯誤。

⚠ **不在 registry 裡的名字會被當成執行檔名直接用**（`run-agent` 從第一天就是吃 cmd 的），
所以 `(agent/run-agent "cat" [])` 一直都跑得起來，不需要先註冊。

