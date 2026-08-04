# CLI

[← 回 pi-shell README](../README.md)


```sh
jpm build                                                       # 產出 build/pi-shell

./build/pi-shell --no-tools "回一個字 ok"                        # 跑 pi
cat notes.md | ./build/pi-shell --no-tools "用一句話總結"         # 自己的 stdin 整段餵進去
./build/pi-shell --claude "回 ok" --disallowedTools Bash Edit Write      # 改跑 claude CLI
./build/pi-shell --claude --model claude-haiku-4-5-20251001 --output-format json "回 ok"

./build/pi-shell --list-agents                                   # registry 裡有哪些 agent
./build/pi-shell --agent qwen-cli "回 ok"                        # 跑自己註冊的 agent
./build/pi-shell --agent-file ~/agents.janet --agent 我的 "回 ok"  # 先載設定檔再跑
```

### 本殼吃掉哪些旗標（其餘一律原樣透傳）

透傳殼消化掉的旗標愈少愈好——多吃一個，子行程就少一個能用的旗標。所以：

| 旗標 | 位置限制 | 做什麼 |
|------|----------|--------|
| `--claude` | **任何位置**（只吃第一個） | 改跑 `claude` 而不是 `pi`（沿用原本的行為） |
| `--agent <名字>` | **只在第一個參數位置** | 跑 registry 裡的某支 agent |
| `--agent-file <檔案>` | **只在第一個參數位置** | 先載入一份 agent 設定檔 |
| `--list-agents` | **只在第一個參數位置** | 列出 registry 裡有哪些 agent 就結束 |

⚠ 「只認第一個位置」是刻意的：**`claude` 自己就有 `--agents` 旗標**，
本殼若在任何位置都攔截，你就再也沒辦法把它送給 claude 了。
放在後面的 `--agent` 一律原樣往下透傳。

其餘（`--model`／`--no-tools`／`--allowedTools`／`--output-format`／`@file`…，連 `--help`）
一律讓給子行程。

- 子行程的 stdout 原樣印出、退出碼原樣回傳；stderr 直接繼承，所以進度訊息照常出現在終端。
- ⚠ 自己的 stdin 不是 tty 時會讀到 EOF——沒人餵就會一直等（unix filter 的正常語意）。
  在腳本／CI 裡測請帶 `< /dev/null`。

## system prompt：靠透傳，本殼不包裝

本模組**沒有**自己的 system prompt 參數——兩支 agent CLI 各自都有旗標，而本殼是薄透傳，
原樣送下去就能用：

```sh
./build/pi-shell --no-tools --append-system-prompt "只用繁體中文回答" "你好"
./build/pi-shell --claude --append-system-prompt "只用繁體中文回答" --disallowedTools Bash Edit Write "你好"
```

```janet
(agent/run-pi ["--no-tools" "--append-system-prompt" "只用繁體中文回答" "你好"])
(agent/run-claude ["--append-system-prompt" "只用繁體中文回答"
                   "--disallowedTools" "Bash" "Edit" "Write" "你好"])
```

⚠ **`--append-system-prompt` 是「附加」，不是「取代」**：agent 自己那份很長的 system prompt
仍然在（也正是它每次呼叫都貴的原因）。真的要**取代**整份的旗標兩支各有各的寫法與限制，
且會關掉它們原本的 agent 行為——需要的話請直接查 `pi --help`／`claude --help`，
**本殼刻意不替你決定**。

> 想要**完全可控的 system 訊息**（單純一則 `role:"system"`、沒有 agent 那一大包），
> 那是 [`../llm-http/`](../../llm-http/README.md) 的場子：`ask` 的第二個參數、
> `with-tools` 的 `:system`、CLI 的 `-s`。
