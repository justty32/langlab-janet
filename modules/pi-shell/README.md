# pi-shell

把**非互動 agent CLI** 包成子行程的**薄透傳殼**。原本只包 `pi`，後來發現 `claude -p`
是完全同一種形狀（非互動、吃 prompt、自帶工具、用 stdin 餵料），所以核心泛化成
`run-agent`；再後來連「有哪些 agent」也做成 **registry**，你手上任何
`<cmd> -p <args>` 形狀的 CLI 都能自己加進來。**目錄名沿用 `pi-shell`，但它不只服務 pi。**

## ⚠ 先讀這一段

`pi` 與 `claude` **預設都帶 bash / edit / write 工具，會真的動你的檔案。**
本模組是**薄透傳**，刻意**不**幫你偷加任何限制旗標——要不要縮限是呼叫端的決定。
（連 agent 設定檔裡都**不能**放限制旗標——「要不要讓 agent 動你的檔案」不該被一份設定檔決定。）

自己在測的時候請務必：

```sh
./build/pi-shell --no-tools "只回一個字 ok，不要用任何工具、不要讀寫任何檔案"
./build/pi-shell --claude "只回一個字 ok" --disallowedTools Bash Edit Write Read
```

⚠ **`claude` 的 `--disallowedTools`／`--allowedTools` 是 variadic**（吃到下一個旗標為止），
所以**提示要寫在它前面**，否則提示會被它當成工具名吃掉：

```
Permission deny rule "只回一個字 ok" matches no known tool — check for typos.
Error: Input must be provided either through stdin or as a prompt argument when using --print
```

⚠ `claude` 那條**每次呼叫都是真金白銀**：實測一句「只回兩個字」約 **$0.016**，
因為每次都重送 Claude Code 的完整 system prompt（見 [`../../FINDINGS.md`](../../FINDINGS.md) 第四節）。
測試請用便宜的模型（`--model claude-haiku-4-5-20251001`）而且**別連打**。

## 跟 llm-http 怎麼分工

| 想做的事 | 走哪 |
|----------|------|
| 自己的**多輪 tool loop**、**圖像輸入**、可控的 `messages[]`、OpenAI 相容格式 | [`../llm-http/`](../llm-http/README.md)（Claude 那條需要 `ANTHROPIC_API_KEY`） |
| **現成就能用的 agent**、不介意它自帶工具與 agent 行為、單次問答 | **本模組**（免 key，但每次呼叫成本高） |

`claude -p` 是 **agent 不是 chat completion 端點**：沒有 `messages[]` 可控、自帶自己的
system prompt 與工具，所以**跑不了呼叫端自己的 tool loop**。要拿 Claude 當**裸模型**，
請走 llm-http 的 `claude` endpoint。

`claude` CLI 走的是**已登入的 OAuth**，不需要 `ANTHROPIC_API_KEY`；`pi` 的 Anthropic 也是 OAuth。

## 這份說明拆成幾支

README 只放「這是什麼、安全提醒、跟 llm-http 怎麼分工」；細節按主題分在 [`doc/`](doc/)：

| 檔 | 內容 |
|----|------|
| [自訂 agent](doc/自訂-agent.md) | 設定認得的欄位、inline／`define-agent`／設定檔三條路 |
| [CLI](doc/cli.md) | 本殼吃掉哪些旗標、其餘怎麼透傳、system prompt |
| [當函式庫用](doc/當函式庫用.md) | `run-agent`／`run-pi`／`run-claude`、公開 API 一覽、拆檔表 |
| [stdin 與子行程](doc/stdin-與子行程.md) | ⚠ 為什麼 stdin 走暫存檔而不是管線、子行程的幾個重點 |

**怎麼 import（路徑規則、`:as`、裝起來用裸名字）→ 見 [`../README.md`](../README.md#怎麼-import-這些模組)。**
