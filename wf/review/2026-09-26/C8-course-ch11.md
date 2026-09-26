# C8 course ch11（todo 專案）審閱

審閱者：fable｜日期 2026-09-26｜範圍：`course/11-1-todo-規劃與骨架.md`、`course/11-1b-todo-骨架.md`、`course/11-2-todo-資料層.md`、`course/11-2b-todo-資料層.md`、`course/11-3-todo-指令層.md`、`course/11-3b-todo-指令層.md`、`course/11-3c-todo-指令層.md`、`course/11-4-todo-測試與打包.md`、`course/11-4b-todo-指令層測試.md`、`course/11-4c-todo-打包成執行檔.md`、`course/11-5-接下來去哪.md`、`course/11-5b-五個區怎麼用.md`、`examples/course/11-1.janet`～`11-5.janet`、`examples/course/11-todo/`

## 總評
整章品質高。課文逐段貼的程式碼跟 `11-todo/` 最終版逐字一致（只差 docstring 與 `parse-id` 的 `defn`／`defn-`），五支範例檔與 `jpm test`、`jpm build`、`jpm clean` 全部實跑通過，課文貼的輸出（含 argparse usage、jpm 訊息、壞檔訊息、凍住環境變數、改非入口檔不重編）都與實測相符。11-5／11-5b 指向的檔案全部存在。b／c 拆檔每支開頭都有「接續」連結，可獨立讀。
最值得先修的一件事：11-4 說「只是 `list` 一下就生出一個空檔，使用者會很困惑」，但 `cli/list` 走 `with-db` 一定 `save`，實跑 `todo list` 真的會生出 `todo.json`（失敗的 `done 9` 也會建檔），課文跟程式行為互相矛盾。其次是「讀者照著打」時 `cli.janet` 的 `(import ./store)` 沒有在 11-3 出現過。

## 發現
- [高][錯誤] `course/11-4-todo-測試與打包.md:61` — 說「只是 `list` 一下就生出一個空檔，使用者會很困惑」當作 `load` 不建檔的理由，但 `todo list`（經 `with-db`）實際上會把空 db 存回去、生出 `todo.json`；`done 9` 失敗也會建檔 — 要嘛改課文（只說 `load` 本身不建檔，建檔是 `with-db` 的事），要嘛讓 `with-db` 只在 code 為 0 且有改動時 save — [實測]（`./build/todo list` 後專案目錄出現 `todo.json`；`done 9 --file none.json` 後 `none.json` 出現）
- [中][範例] `course/11-3-todo-指令層.md:42-66` — `with-db` 用到 `store/…`，但這課從頭到尾沒貼 `cli.janet` 頂端的 `(import ./store)`（只有 11-1b 的箭頭圖提過）；讀者照 11-3 一段段打會拿到 `unknown symbol store/data-path` — 在「parse」節前面補一段兩行 import（`spork/argparse :as ap`、`./store`） — [疑]
- [中][錯誤] `course/11-4-todo-測試與打包.md:38` — 「目錄名稱裡塞了時間和亂數，兩支測試同時跑也不會撞在一起」：`math/random` 沒 seed，每個新行程第一次都回同一個值 0.487181…，亂數那段在跨行程時完全不防撞，真正防撞的是 tag 不同 — 改成「時間加 tag」或改用 `os/cryptorand`／`(math/rng (os/time))` — [實測]（`janet -e '(print (math/random))'` 連跑兩次同值）
- [中][結構] `course/11-1b-todo-骨架.md:76` 與 `course/11-3b-todo-指令層.md:38` — 前者說「檔案要等第一次 `save` 才出現」，後者說 `list` 也會把檔案存回去一次；兩段各自都對，但沒互相指，讀者到 11-4:61 就會被繞暈 — 在 11-3b:38 加一句「所以 `list` 會順手建出 `todo.json`」 — [實測]
- [低][錯誤] `course/11-1-todo-規劃與骨架.md:33` — 「接下來四課會一支檔一支檔讀懂它」，實際是 11-2～11-4 三課，11-5 不講檔案 — 改「三課」 — [疑]
- [低][結構] `course/11-1b-todo-骨架.md:42`、`course/11-2-todo-資料層.md:34` — 「11-4 會用到／11-4 會實測」指的內容都在 `11-4c`，讀者翻 11-4 找不到 — 改指 11-4c — [疑]
- [低][文風] `course/11-1-todo-規劃與骨架.md:65` — 「例子用英文只是因為 `# =>` 比對不收中文」是 repo 測試工具的內部理由，讀者不知道 `# =>` 比對是什麼；`examples/course/11-1.janet:8` 給的理由又是另一個（pp 逃逸） — 統一成 2-2 講過的「pp 會把中文逃逸」或直接刪 — [疑]
- [低][難懂] `course/11-2b-todo-資料層.md:74` — `(import ./11-todo/todo/store)  # path 是暫存目錄裡的檔`：註解掛在 import 那行，但 `path` 在片段裡從沒定義 — 補一行 `(def path …)` 或把註解移到 `store/load` 那行 — [疑]
- [低][結構] `course/11-5-接下來去哪.md:54` 與 `course/11-5b-五個區怎麼用.md:25` — 前者數出 cheatsheets 9 支 .md，後者說「七頁速查表」（實際 README＋核心＋核心b＋6 頁＝9 檔、8 頁） — 11-5b 改「八頁（核心分兩支）」或說明數字含 README — [實測]
- [低][錯誤] `course/11-5-接下來去哪.md:52-56` — 五個數字（96／24／9／20／6）現在對，但每新增一支檔就過期 — 加一句「數字會隨 repo 長大變動」 — [實測]
- [低][範例] `course/11-3c-todo-指令層.md:73-75` — 說 `--help` 回 1 但沒示範怎麼分；可加一行 `(if (find |(or (= $ "--help") (= $ "-h")) args) …)` 當提示 — [實測]（`add --help` exit 1）

## 沒來得及看的
- 11-5b:21「Janet 內建的部分是對著 root-env 逐一核過」只確認 `reference/README.md:17` 有同樣宣稱，沒實際抽查。
- `test/cli.janet` 在 `TMPDIR` 含空白或非 ASCII 路徑下是否仍過（沒試）。
- 其餘課文與範例輸出皆已逐段對照實跑結果。
