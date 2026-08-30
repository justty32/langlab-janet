# conventions — 程式碼慣例（碰原始碼的工作流共用）

[common/README](README.md)｜[INDEX](../../INDEX.md)

碰原始碼的工作流（feature-dev / refactor / investigation）共用這套規矩：**寫碼時要遵守什麼**。哪個檔負責什麼領域、測試在哪 → [code-map](code-map.md)；真相層優先序也在 [code-map](code-map.md)。結構整理原則 → [STRUCTURE](../../STRUCTURE.md)。

## 慣例

| 項目 | 規矩 | 怎麼檢查 |
|------|------|---------|
| 檔案大小 | `html/` 以外每支檔 **≤150 行且 ≤8192 bytes**；超標按**內容語意**拆，原檔名保留當入口（`10` → `10b`／`10c`／`10d`）| `bash wf/tools/wf-lint.sh --strict .` 的 `oversize` 欄要是 0 |
| 模組分層 | 一個模組一個資料夾，`init.janet` 是**只做 re-export 的門面**，實作分成職責單一的小檔（`llm-http` 17 支、`pi-shell` 7 支）| `init.janet` 裡不該有 `defn`，只有 `import` 與 re-export |
| 命名 | 檔名與識別子一律 kebab-case（`cli-flags.janet`、`chat-url`）；謂詞結尾 `?`（`env-ready?`、`truthy?`）；**有副作用的結尾 `!`**（`reset-endpoints!`、`load-endpoints!`）| `grep -n 'defn [a-z-]*!' ` 出來的每一支都真的有副作用 |
| 註解語言 | **繁體中文**；程式碼識別子、shell 指令、技術名詞（`fiber`、`marshal`、PEG）保留原文 | 目視 |
| 檔頭註解 | 每支非門面檔開頭寫一句「這支檔只做什麼」；踩過的坑用 `⚠` 開頭寫在**當場那一行**，不要只寫在 FINDINGS | 新檔第一行是 `#` 註解 |
| `project.janet` | `declare-source` 的 `:source` **一定逐檔列，不要給目錄**——jpm 是 `cp -rf` 過去的，給目錄會多包一層 `<modpath>/llm-http/llm-http/…`，import 路徑就跑掉 | 新增檔案後 `jpm test` 仍綠、且 `jpm build` 不報 File not found |
| 相依 | 新套件先寫進 `project.janet` 的 `:dependencies` 再 `jpm deps`；**沒有 lockfile**，所以版本差異靠 `docs/00` 記的版本號對 | `jpm deps && jpm test` |
| breaking change | 改公開介面前先全域 `grep` 受影響處（`modules/`、`test/`、`docs/`、`snippets/`、`examples/` 都要看），同一個 commit 一起改 | `jpm test` ＋ `wf-lint` 連結檢查 |
| 測試 | 每支測試最後印一行「…測試通過 ✓」（`jpm test` 成功時很安靜，沒這行看不出有沒有真的跑到底）| `jpm test` 輸出每支都有 ✓ |
| `test/` 的共用工具檔 | `jpm test` 會把 `test/` 底下**每一支** `.janet` 都當測試跑，所以共用檔**只能有定義、不能有會印東西或有副作用的頂層程式碼**（見 `test/util.janet` 檔頭）| 單獨跑 `janet test/util.janet` 應該零輸出、exit 0 |
| 文件裡的程式碼 | 每段輸出都是**實測貼回來的**，不是推測的（鐵律 5）——包含錯誤訊息的原文 | 改動前先 `janet -e '…'` 跑一次，把真實輸出貼回去 |
