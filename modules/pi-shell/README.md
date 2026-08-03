# pi-shell

把**非互動 agent CLI** 包成子行程的**薄透傳殼**。原本只包 `pi`，後來發現 `claude -p`
是完全同一種形狀（非互動、吃 prompt、自帶工具、用 stdin 餵料），所以核心泛化成
`run-agent`，`pi` 與 `claude` 各是一個便利包裝。**目錄名沿用 `pi-shell`，但它不只服務 pi。**

## ⚠ 先讀這一段

`pi` 與 `claude` **預設都帶 bash / edit / write 工具，會真的動你的檔案。**
本模組是**薄透傳**，刻意**不**幫你偷加任何限制旗標——要不要縮限是呼叫端的決定。

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

## CLI

```sh
jpm build                                                       # 產出 build/pi-shell

./build/pi-shell --no-tools "回一個字 ok"                        # 跑 pi
cat notes.md | ./build/pi-shell --no-tools "用一句話總結"         # 自己的 stdin 整段餵進去
./build/pi-shell --claude "回 ok" --disallowedTools Bash Edit Write      # 改跑 claude CLI
./build/pi-shell --claude --model claude-haiku-4-5-20251001 --output-format json "回 ok"
```

- **`--claude` 是唯一由本殼消化掉的旗標**，其餘一律原樣往下透傳
  （`--model`／`--no-tools`／`--allowedTools`／`--output-format`／`@file`…，連 `--help` 都讓給子行程）。
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
> 那是 [`../llm-http/`](../llm-http/README.md) 的場子：`ask` 的第二個參數、
> `with-tools` 的 `:system`、CLI 的 `-s`。

## 當函式庫用

**怎麼 import（路徑規則、`:as`、裝起來用裸名字）→ 見 [`../README.md`](../README.md#怎麼-import-這些模組)。**
下面假設你的檔案在根目錄下一層（`test/`、`bin/` 那種）：

```janet
(import ../modules/pi-shell/init :as agent)

# 核心：跑任何「<cmd> -p <args...>」形狀的 agent CLI
(agent/run-agent "pi" ["--no-tools" "回 ok"])       # → @{:out "ok\n" :code 0}

# 兩個便利包裝
(agent/run-pi ["--no-tools" "用一句話總結"] "要總結的長文…")
(agent/run-claude ["--disallowedTools" "Bash,Edit,Write" "回 ok"]
                  nil                               # stdin，可省略
                  "claude-haiku-4-5-20251001")      # model，可省略

# claude 的 JSON 信封版：順便拿到花了多少錢
(def r (agent/run-claude-json ["--disallowedTools" "Bash,Edit,Write" "回 ok"]))
(r :ok)                                             # 成功?（exit 0 且 is_error 為假）
(r :text)                                           # 答案本文
(get-in r [:envelope :total_cost_usd])              # 這次花了多少

# 探測（只問 --version，不請它做事）
(agent/pi-available?) (agent/claude-available?)

# 更底層：跑任何指令，不墊 -p
(agent/run ["cat"] "餵進去的內容")                    # → @{:out "餵進去的內容" :code 0}
```

## 拆檔

| 檔案 | 管什麼 |
|------|--------|
| `proc.janet` | 子行程管線（`os/spawn`／`drain`／`run`／`available?`），**不認識任何 agent** |
| `init.janet` | 門面：agent 的知識（指令名、旗標形狀）＋ `run-agent`／`run-pi`／`run-claude` |
| `main.janet` | CLI 進入點 |

## ⚠ 為什麼 stdin 走暫存檔而不是管線

**這是時序問題，不是管線壞掉。**

`pi` 在**啟動當下**檢查 stdin 有沒有東西可讀。shell 的 `echo x | pi` 在 pi 開始跑之前，
資料就已經躺在管線 buffer 裡了；但 `os/spawn` ＋ `:in :pipe` 是**先 spawn、後寫入**，
pi 檢查的那一瞬間管線還是空的，於是它判定「沒有管線輸入」——實測會回你
「無法讀取 stdin，沒有輸入」。

（`claude -p` 跟一般 node 程式是**事件式**等到 EOF 才收工，對這個時序不敏感，
所以它們用管線也收得到——很容易讓人誤判成「管線沒問題、是 pi 壞了」。）

修法是把 stdin 換成**內容已經就緒的檔案句柄**，子行程一開工就讀得到：

```janet
(def f (file/temp))                 # 匿名暫存檔，close 掉就消失，不用善後
(file/write f stdin-str)
(file/flush f)
(file/seek f :set 0)                # ★ 一定要倒帶！
(os/spawn cmd :p {:in f :out :pipe})
```

⚠ **`(file/seek f :set 0)` 沒做的話，子行程會從檔尾開始讀 = 靜默讀到空**，
不會有任何錯誤訊息，非常難查。

這條路對 `pi` 與 `claude` **都有效**，所以 `proc.janet` 統一走它，不為兩支 agent 分岔；
stdin 那半也因此不再需要背景 fiber。**但讀 stdout 仍然維持「邊跑邊讀」**（見下一節）。

## 子行程的幾個重點

管線寫法照 [`../../snippets/pipe-to-child/main.janet`](../../snippets/pipe-to-child/main.janet)：

- `(os/spawn cmd :p {:out :pipe})` 才會拿到 stdout 管線；`:p` = 走 PATH 找執行檔。
- ★ **stdout 一定要邊跑邊讀**（背景 fiber `drain`），別改成「先 `os/proc-wait` 再讀」——
  輸出量一大就塞爆 pipe buffer 死鎖。
- stdin 走暫存檔句柄（見上一節）；沒東西要餵時才給管線並立刻 `(:close (proc :in))` 送 EOF。
- ★ 收工一定要 `(os/proc-wait proc)`，否則留下殭屍行程。
- stderr 不接管線、直接繼承，所以子行程的進度訊息照常出現在終端。

刻意**不**加 `:x`——非 0 退出碼是**資料**（回在 `:code` 裡），不是例外。
