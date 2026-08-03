# 缺口記錄

使用者練習 Janet 時，若詢問的東西在這個資料夾（janet-lab）目前沒有涵蓋，記在這裡。
之後交給另一個 agent 依此補完。**只記缺口，不記已解決的問答。**

格式：`- [日期] 使用者問了什麼 / 目前資料夾沒有涵蓋的地方 → 建議補在哪`

---

- [2026-08-03] 使用者問「用 jpm new 建新專案」→ docs/05-jpm-與專案.md 只講既有專案的 jpm deps/test/build/clean 日常指令，完全沒提 `jpm new-project` / `new-c-project` / `new-exe-project` 這三個 scaffold 指令（含互動問答 author/description、產生的目錄結構）→ 建議在 05 補一節「建立新專案」講這三個指令的差異與互動流程。
- [2026-08-03] 使用者用 `jpm new-project` 生的專案沒有 bin/、沒有 declare-executable，靠的是 Janet CLI 的隱含規則「`janet 檔案.janet` 直接執行時，載入完若環境有 `main` 會自動呼叫」（`use` 進來的 `main` 也算，所以 `jpm test` 會連帶把 main 印出來）→ janet-lab 目前沒有任何一篇文件明講這條「top-level main 自動被呼叫」的規則，01-語言速成.md 或 05-jpm-與專案.md 都只在 argparse 範例裡帶過 `defn main`，沒解釋這是 runtime 通用機制 → 建議補在 01 或 05，講清楚這條規則跟它對「不用 declare-executable 也能跑」「test 檔 use 進 main 會被連帶呼叫」的影響。
- [2026-08-03] 使用者問「想要一個可以被 import 的專案」→ 05-jpm-與專案.md 只講「裝別人的套件」（官方清單／git URL），完全沒講跨專案 import 自己本地寫的東西：(1) monorepo 式相對路徑 import（`(import ../其他專案/其他專案/init)`，靠的是 import-files 那篇講的相對路徑規則，但沒人把它跟「另一個 jpm 專案」接起來講）；(2) 把本地 repo 裝成套件要先 `git init`＋至少一個 commit，且 `jpm install` 的 bundle 字串一定要含冒號才會被當成遠端位址而非官方清單短名，本地路徑要寫成 `git::file:///絕對路徑` 才吃得下（`./相對路徑`或純目錄路徑都會報 "bundle ... not found"）；`--local`/`-l` 裝到專案自己的 jpm_tree vs 不加裝到全域 `~/.local/lib/janet/` 這個差異目前文件裡也沒交代 → 建議在 05 補一節「引用自己另一個本地專案」，把這兩條路都寫清楚。
- [2026-08-03] 使用者問「沒有 jpm run 嗎？」（以為是 `cargo run`／`npm run` 那種「編完直接執行」）→ 實際上 `jpm run` 是 **make 式的 rule runner**，跑的是 `jpm rules` 列出來的 rule（build／clean／install／test／`build/<exe>`…），**編完不會幫你執行**；要「一鍵編完就跑」得自己在 project.janet 加 `(phony "run" ["build"] (os/execute ...))`。docs/05-jpm-與專案.md 的「日常指令」表完全沒有 `jpm run`／`jpm rules`／`jpm rule-tree`，也沒提 `phony`／`rule` 自訂規則這整套 → 建議在 05 補一節「jpm 的 rule 系統」，順帶點明它跟 cargo/npm 的 run 語意不同（這是轉語言過來的人一定會踩的預期落差）。
- [2026-08-03] 做 modules/llm-http 時要用 spork/http **發 POST**（帶 body 與 header）→ snippets/http-local.janet 只示範 `http/request "GET"`，docs/15-ev-channel-net.md 也只講 net 層，沒有任何一處講 client 端 POST：`(http/request "POST" url :body … :headers …)`、**回應的 `:body` 是 buffer 要 `(string …)` 包一層才能餵 json/decode**、`:status` 要自己判 2xx。順帶：**spork/http 的 client 沒有 TLS**（底層是 `net/connect`），https 打不了；而且它是「讀完整份 response 才回」，**SSE／`stream: true` 這種逐行串流做不出來** → 建議在 03-json 或 15 補一節「用 spork/http 當 client 打 API」，把 POST 寫法、buffer/status 兩個雷、以及 TLS 與串流兩個先天限制講清楚。
- [2026-08-03] 同上，`spork/json` 的 `json/encode` **會把非 ASCII 逃逸成 `\uXXXX`**（`{:cond "晴"}` encode 出來是 `{"cond":"\u6674"}`）→ docs/03-json.md 只講 encode/decode round-trip，沒提這件事；雖然是合法 JSON、對端解得開，但自己 print 出來 debug 時會以為壞掉。另外 `json/decode` 第二個參數給 `true` 才會把 key 變成 keyword（不給就是字串，`get-in [:choices 0]` 會全部落空）——這條 03 有帶到但沒強調它有多容易踩 → 建議在 03 補一小段「encode 的 unicode 逃逸」與把 keyword 那個參數講成醒目提醒。
- [2026-08-03] 使用者自己把 `hello` 改成 `(+ "Hello!" word)` 想接字串，結果炸掉（`+` 是純數字加法，不是字串串接）→ 01-語言速成.md／02-資料結構.md 裡雖然範例都用 `(string ...)` 接字串，但沒有任何一段**明講「`+` 只能加數字，字串串接要用 `string`」**這個常見雷（尤其對從 Python/JS 轉來的人）→ 建議在 01 或 02 補一小段對照表：`+`/`-`/`*` 只吃數字，字串連接是 `string`，並提一下錯誤訊息長怎樣（`could not find method :+ for "..."`）方便以後認得。
