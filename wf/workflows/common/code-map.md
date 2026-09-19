# code-map — 程式碼導航 index（哪個檔負責什麼）

[common/README](README.md)｜[INDEX](../../INDEX.md)

碰原始碼前先查這張表，只讀相關領域列出的檔；動完再照維護鏈把表更新回去。寫碼慣例本身在 [conventions](conventions.md)。

## 領域表

| 領域 | 檔案 | 職責 | 測試在哪 |
|------|------|------|---------|
| **示範專案本體** | `janet-lab/init.janet`、`bin/main.janet` | 教學用的最小可跑專案：純函式核心 ＋ argparse CLI 進入點。**它存在的目的是被教學引用**，不要為了功能而長大 | `test/basic.janet` |
| **llm-http · endpoint 層** | `modules/llm-http/{endpoints,defaults,builtin,spec,registry,resolve,config}.janet` | 「要打哪、用什麼金鑰」：`defaults` 讀 `LITELLM_BASE`／`LITELLM_API_KEY` 並組 chat-url，`builtin` 是六筆內建 endpoint 的純資料（含直打 https 的 `claude-direct`／`deepseek-direct`），`spec` 純函式驗證一份設定合不合法，`registry` 管誰在表裡，`config` 只 parse 不 eval 地載設定檔，`resolve` 組出可以打的 cfg | `test/llm-http-registry.janet`、`test/llm-http-config.janet` |
| **llm-http · 傳輸與對話** | `modules/llm-http/{client,transport,transport-curl,dispatch,retry,chat,media,tools,structured,models}.janet`、`{provider-anthropic,anthropic-req,anthropic-res}.janet`、`{sse,stream,stream-http,stream-curl,stream-anthropic}.janet` | `transport` 走 spork/http，`transport-curl` 子行程呼叫 curl（https 才打得通），`dispatch` 決定走哪條、`retry` 退避重試；`chat` 是對話語意，`media` 圖檔轉 data URI，`tools` 跑多輪 tool loop，`structured` 是 JSON 輸出，`models` 列模型；`provider-anthropic`＋`anthropic-req`／`-res` 在本機做 OpenAI ↔ Anthropic 雙向轉換；`sse` 解 event-stream，`stream*` 是串流的三條實作與門面 | `test/llm-http-{params,media,server,curl,anthropic,anthropic-loop,stream,extras}.janet`（全部同行程假後端）|
| **llm-http · CLI** | `modules/llm-http/{cli,cli-flags,cli-args,cli-list,main}.janet` | 旗標定義與 usage 文字、命令列字串 → Janet 值、`--list` 輸出；`main.janet` 只是薄進入點 | `test/llm-http-cli.janet` |
| **agent** | `modules/agent/{init,registry,sandbox,tools-fs,tools-search,tools-shell,tools-http,tools-misc,presets,memory,memory-io,trace,agent,cli,cli-flags,main}.janet` | 站在 llm-http 上面的 agent 層：`registry` 定義工具長什麼樣，`sandbox` 管路徑可不可以碰，`tools-*` 是各類工具（檔案／grep／shell 白名單／http-get／`now`／`calc`），`presets` 一次組出預設安全的整組，`memory`＋`memory-io` 管記憶與整輪截斷，`trace` 把事件變成一行字，`agent` 是 `make-agent`／`run`，`cli` 是 CLI（`main` 只是進入點）| `test/agent-{tools,sandbox,shell,memory,loop,cli}.janet`（`test/agent-fake.janet` 是共用的假後端，只有定義）|
| **aos** | `modules/aos/{init,fsx,land,proc,deliver,call,inst,async}.janet` | 把 aos 的「資料夾當程式、檔案當指令」綁進 Janet：`fsx` 是檔案協定底層，`land` 認地與算路徑，`proc` shell 出去推原型 `aos.py`，`deliver`／`call`／`inst`／`async` 是投遞、同步呼叫、檔案當指令、脫節呼叫。⚠ 測試一律把 `AOS_HOME` 指到暫存目錄 | `test/aos-{call,inst,async}.janet`（`test/aos-util.janet` 只有定義）|
| **pi-shell** | `modules/pi-shell/{init,proc,spec,agents,config,run,cli}.janet` | 把非互動 agent CLI（`pi -p`／`claude -p`）包成子行程的薄透傳殼：`proc` 是不認識任何 agent 的管線，`agents` 是 registry，`run` 提供 `run-agent`／`run-pi`／`run-claude` | `test/pi-shell-agents.janet`、`test/pi-shell-cli.janet`、`test/pi-shell-proc.janet` |
| **測試共用工具** | `test/util.janet`、`test/agent-fake.janet`、`test/aos-util.janet`、`test/doc-examples-skip.janet` | `err-of`：跑一個一定會失敗的 thunk，把錯誤訊息當字串回傳，用來驗「錯誤訊息是不是看得懂的中文」；另外三支分別是 agent 的假後端、aos 的暫存地、doc-examples 的「不跑／不比對」名單。⚠ 它們也會被 `jpm test` 當測試跑一遍，所以只能有定義 | 它們自己（單獨跑應零輸出、exit 0）|
| **專案宣告** | `project.janet` | 依賴、四個 `declare-executable`、五個 `declare-source`（janet-lab／llm-http／pi-shell／aos／agent）。⚠ `:source` 一定逐檔列，見 [conventions](conventions.md) | `jpm build` 不報錯即通過 |

⚠ **教學內容不在這張表裡。**`docs/`、`reference/`、`examples/`、`snippets/`、`html/` 是**產物不是原始碼**，導航走 [INDEX](../../INDEX.md) 與各自的 README。這張表只管「改了會讓 `jpm test` 變紅」的東西。

## 真相層優先序

各專案可以改自己的優先序，但必須明確。預設：

```text
code/tests > schema/examples/fixtures > code map > docs > generated
```

- 上層與下層衝突時，**以上層為準並修正下層**。
- generated（產生出來的檔、html）永遠不是唯一真相。
- 原始來源與摘要衝突時，以**原始來源**為準。
- code map 是**導航不是規格**；行為以 code/tests 為準。

## 維護鏈：程式碼 > code map > 文檔

**優先級**（衝突或時間不夠時，依序保持一致）：程式碼 > code map > 文檔。
**code map 與程式碼衝突時以程式碼為準，立刻改 code map。**

1. **修改前**：先讀本表找到相關領域，只讀清單裡的檔——不讀無關領域的檔。
2. **修改後**：新增／刪除了原始碼檔案，或某檔職責顯著改變，必須同步更新本表。
3. 原始碼裡**不加**「對應 code map」的註釋（維護成本過高）；反向查找直接 grep 本檔。
4. 迭代期間本表可暫時落後，**commit 前必須對齊**（見 [feature-dev](../feature-dev/README.md)）。
