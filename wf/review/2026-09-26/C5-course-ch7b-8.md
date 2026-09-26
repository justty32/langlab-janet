# C5 course ch7b-8 審閱

審閱者：fable｜日期 2026-09-26｜範圍：`course/7-3-讀錯誤訊息.md`、`course/7-3b-尾呼叫與-trace-的坑.md`、`course/8-1-讀寫檔案.md`、`course/8-1b-讀寫檔案.md`、`course/8-2-目錄與路徑.md`、`course/8-2b-目錄與路徑.md`、`course/8-3-命令列參數.md`、`examples/course/7-3.janet`、`examples/course/8-*.janet`

## 總評
（待補）

## 發現

### 7-3 / 7-3b（錯誤訊息、trace）
- [中][錯誤] `course/7-3b-尾呼叫與-trace-的坑.md:27` — 說 `(tail call)` 標記「表示這一格自己做了尾呼叫」，下一句又說「因為 `第二層` 是被 `第一層` 尾呼叫的」，兩句互相矛盾；實際上標記是「這一格是被尾呼叫進來的（頂掉了呼叫者的位置）」，`第二層` 本身 `(+ 1 (第三層 x))` 並沒有做尾呼叫 — 刪第一句，只留「被尾呼叫進來」的解釋，並補一句「真的做了尾呼叫的那一格根本不會出現」 — [實測]（`tail.janet`／`notail.janet` 輸出與課文一致，標記落在被尾呼叫的 `第二層`，不在做尾呼叫的 `第一層`）
- [低][錯誤] `course/7-3-讀錯誤訊息.md:53`、`:123` — 「參數個數寫錯也是 compile error」寫成絕對句；只有呼叫對象在編譯期是已知常數（`defn`／`def`）才成立，`var` 或參數傳進來的函式是 runtime error，訊息變成 `<function 0x…> called with 1 argument, expected 2`，`try` 接得到 — 加半句「（前提是呼叫的名字是 `defn` 出來的）」，或在對照表補一列 — [實測]
- [低][難懂] `course/7-3-讀錯誤訊息.md:47`、`:114`、`:124` — 同一個錯出現兩種文字：`for nil`（nil 在第一格）與 `for 1 or :r+ for nil`（nil 在第二格），課文三處交替出現卻沒說為什麼不一樣，讀者對照表格會找不到自己那句 — 在對照表那列加一句「nil 在第二個參數時會多出 `or :r+ for nil`」 — [實測]
- [低][範例] `examples/course/7-3.janet:48`、`:68` — 「在程式裡自己印 trace」那段沒走 `印trace`（沒 `flush`），`2>&1` 重導時 `error: 壞了` 跑到段落標題前面，正好踩到 7-3b:81 自己講的坑；練習 3 標題寫「只剩兩行」，實際 stderr 是 `error:` ＋ 一行 `in 第三層`，而課文要的是改 `tail.janet` 檔（會多一行 `thunk`），兩邊數字對不上 — 第 48 行改用 `印trace`；練習 3 標題改「只剩 `第三層` 一格」 — [實測]
- [低][文風] `course/7-3-讀錯誤訊息.md:7` — 「然後懷疑人生」；`:9` 一句話塞進「stack trace、呼叫堆疊、誰呼叫誰」三層括號解釋，讀起來斷氣 — 拆成兩句 — [疑]

### 8-1 / 8-1b（讀寫檔案）
- 課文所有 `# =>`、印出結果與 `examples/course/8-1.janet` 全部實測一致：`spit` 回 `nil`、`slurp` 回 buffer、`:ab` 附加、`os/stat` 不在回 `nil`、`file/open` 不在回 `nil`、`with` 裡冒出 `unknown method :close invoked on nil`、`file/read :line` 尾巴留 `\n`、檔尾回 `nil`、`:r+` `:a+` `:rb` 都開得起來 — [實測]
- [中][難懂] `course/8-1b-讀寫檔案.md:90-91` — 只說「錯誤要到區塊結束才冒出來」，沒解釋為什麼身體裡 `(file/read nil :all)` 那個更好懂的錯（`bad slot #0, expected core/file, got nil`）不見了：`with` 展開成 `defer`，身體的錯被暫存，收尾 `(:close nil)` 又炸，後炸的蓋掉先炸的 — 加一句「身體其實先炸了，但 `with` 收尾時 `(:close nil)` 再炸一次，你看到的是第二個」，這也呼應 7-2 的 `with` 坑 — [實測]
- [低][範例] `course/8-1-讀寫檔案.md:23-29` — 每段範例都重複四行「算 tmp、mkdir、rm、rm」樣板，四段共十六行，真正教的只有兩行；且 `os/rm` 刪目錄這件事（`os/rm` 對空目錄也行）沒說 — 第一段講清楚後，之後的段落只留關鍵行，樣板收進 `examples/course/8-1.janet` 的 `at` 輔助函式（它已經這樣做了） — [疑]
- [低][範例] `course/8-1b-讀寫檔案.md:38-44` — 模式表沒給「模式錯了會怎樣」：`(file/open p :x)` 會拋 `invalid flag x, expected w, a, or r`（這是 `file/open` 唯一會立刻拋錯的情況，跟「打不開回 nil」形成對照） — 表下加一行 — [實測]
- [低][結構] `course/8-1-讀寫檔案.md:62` 與 `course/8-1b-讀寫檔案.md:103` — 8-1 說「為什麼要多那個 b，續篇講」，8-1b 講了但只有一句「`spit` 給 `:a` 就變文字模式」，沒說 `spit` 預設模式其實是 `:wb`，讀者不知道「預設是二進位」是從哪來的 — 在 8-1b:103 明寫「`spit` 第三個參數預設 `:wb`」 — [疑]
