# C5b course ch8-2～8-3 審閱（續 C5）

審閱者：fable｜日期 2026-09-26｜範圍：`course/8-2-目錄與路徑.md`、`course/8-2b-目錄與路徑.md`、`course/8-3-命令列參數.md`、`examples/course/8-2.janet`、`examples/course/8-3.janet`；總評見 `wf/review/2026-09-26/C5-course-ch7b-8.md`

## 發現（續）

### 8-2 / 8-2b（目錄與路徑）
- 課文所有 `# =>` 與 `examples/course/8-2.janet` 輸出實測一致：`os/stat` 鍵表、`:size` 6、`:mode` `:file`／`:directory`、`os/mkdir` 二次回 `false`、`Directory not empty: …`、`No such file or directory: no-such-8-2/deep`、`path/dirname` 帶尾斜線、`path/ext "Makefile"` 回 `nil`、`path/join "out/" "/data.txt"` 收斜線、`sh/list-all-files`／`sh/create-dirs` 存在 — [實測]
- [中][錯誤] `course/8-2-目錄與路徑.md:37` — 說 `:mode` 會有 `:link`（捷徑）；`os/stat` 跟 C 的 `stat()` 一樣會跟著 symlink 走，對 symlink 回的是目標的型別（實測 `:file`），`:link` 只有 `os/lstat` 才會回 — 改成「`:link` 要用 `os/lstat` 才看得到，`os/stat` 會穿過捷徑」或直接刪 `:link` — [實測]
- [低][範例] `course/8-2-目錄與路徑.md:83`、`course/8-2b-目錄與路徑.md:56-61` — `os/dir` 對不存在的目錄會拋 `cannot open directory X: No such file or directory`，課文與坑段都沒提，`txt-total` 給錯目錄就炸 — 在 `os/dir` 段加一句，或 `txt-total` 開頭 `(assert (os/stat dir :mode))` — [實測]
- [低][錯誤] `course/8-2b-目錄與路徑.md:20` — 「Windows 會是 `"a\\b\\c.txt"`」沒法在本機驗，`spork/path` 依 `(os/which)` 選 win32 版是合理推測 — 標成「（未實測）」或引 docs/19b 的說明 — [疑]

### 8-3（命令列參數）
- `(dyn *args*)` 在 `janet args.janet 3 hello --x` 下實得 `@["args.janet" "3" "hello" "--x"]`、`main` 收到同內容 tuple；四種 kind、沒給選項回 `nil`、`:default` 沒位置參數回 `nil`、`-` 被吃掉、`:map scan-number`、未知選項／漏值／`:required` 三種都印 usage 回 `nil` — 全部與課文一致 [實測]
- [中][錯誤] `course/8-3-命令列參數.md:91` — 說 `--help` 會「印出：usage: demo [option] ...」；實測 `--help` 只印說明句與選項表，**沒有** `usage:` 那行，`usage: demo [option] ...` 只在 usage error（未知選項、漏值、required 沒給）時才印 — 改成「印出說明句跟每個選項的說明」；:95 可補一句「出錯時最上面多一行 `usage error: …` 跟 `usage: demo [option] ...`」 — [實測]
- [中][範例] `examples/course/8-3.janet:6` — 註解叫讀者用 `3 hello --x` 跑這支檔，但檔尾「真的接上命令列」那段沒 `:args`，會把 `--x` 當未知選項印 usage 然後 `(os/exit 1)`，讀者看到程式中途死掉會以為自己弄壞了 — 註解改成叫他跑課文的 `args.janet`，或改用 `-n Bob --upper x.txt` 那組 — [實測]
- [低][難懂] `course/8-3-命令列參數.md:9` — 「動態綁定你先當成全域設定值」後面立刻又講 `*args*` 是別名，兩個新名詞疊在一段；`*args*` 別名這句對本課沒用（範例只用一種） — 只留 `(dyn :args)`，`*args*` 移到「想更深」 — [疑]

## 結構、文風（整批）
- [低][結構] 七支檔都在 150 行／8192 bytes 內；連結全部指得到；AI 味套話 grep 零命中 — [實測]
- [低][結構] `course/8-2-目錄與路徑.md` 沒有「你會踩的坑」與練習，全放 8-2b；8-1 也是坑在 8-1 但練習在 8-1b。兩章的 b 檔分工不一致 — 統一成「a 講機制＋動手、b 講坑＋練習＋想更深」 — [疑]
- [低][結構] `course/8-1-讀寫檔案.md:108` 只寫「續篇」沒有「下一課」導航，`course/8-2-目錄與路徑.md:115` 同；`7-3:131` 同 — 每支 a 檔尾巴補「上一課／續篇」兩個連結 — [疑]

## 沒來得及看的
- 8-3 的小練習解答（`examples/course/8-3.janet:73-85`）只跑過、沒逐行對照題目；`docs/34`、`docs/04` 與課文重疊處只 grep 確認有對應段落，沒比對內容是否矛盾。
- 文風細審（句長、簡體用字對照 `zh-tw.md`）沒做。
