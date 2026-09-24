# decisions — 決策記錄（為什麼選 A 不選 B）

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

留下「為什麼」：git log 找得回改了什麼，找不回**為什麼放棄方案 C**。

**何時用**：在兩個以上可行方案裡選一個，且日後可能被問「當初為什麼」。
**何時不用**：只有一條路，或隨時可回頭的小事。決策過程要結構化評估 → knowledge 包的 decide 工作流，結論再落到這裡。

## Done when

- 下表新增一列，且「未選方案與原因」「前提」兩欄非空。

## 記錄（新的在上）

| 日期 | 決定 | 未選方案與原因 | 前提（變了就重看）|
|------|------|---------------|-----------------|
| 2026-09-24 | **教學分兩層**：`course/` 大白話照順序上課、`docs/` 密集查資料，不改寫 docs | 把 docs 逐篇改成白話：90 篇每篇已到 150 行上限，白話版更長要全部拆檔、doc-examples 的行號名單全失效、而且會失去給有底子的人快速掃的版本 | 使用者 2026-09-24 說現有教學不好、要大白話；若之後要求 docs 也白話化再重看 |
| 2026-09-19 | **主 session 只派線不做事**，模型分三級（困難 fable／普通 opus／簡單 sonnet），收工開一條整合線統一補索引與 commit → [dispatch](dispatch.md) | 主 session 自己動手：它的 context 要留給盤點與調度，寫一支檔就吃掉一大塊，之後派線品質下滑。全部派同一級模型：簡單活（補一列表格、改連結）用 fable 是純浪費，難活（改 kernel、跨多檔重構）用 sonnet 會做壞。各線自己 commit：平行時 `git add -A` 會互相撈到別條線的暫存 | 使用者 2026-09-19 裁示「可以開無限個 agent、主 session 盡量不要自己做事」。headcount 或模型階梯變了就重看；只開一兩條線時不必走整合線 |
| 2026-09-19 | 七頁速查表從**手寫 html 轉成 md**（`cheatsheets/`），html 版刪除 | 維持手寫 html：GitHub 上看是原始碼不是內容、`grep` 搜不到、不受 ≤150 行／≤8192 bytes 的檔案大小慣例約束（實際已長到單頁難掃），而且版型要一頁一頁手維護。轉成 md 後閱讀器自動套兩欄卡片版，同一份內容兩邊都好看 | 閱讀器能把 `cheatsheets/` 區自動渲染成兩欄卡片（`html/style.css` 的 `.cheat`）。若哪天需要速查表獨有的互動版型，那一頁才另議 |
| 2026-09-19 | 網站走「**全部 md ＋ 閱讀器 ＋ Python 打包**」：`html/index.html` 是唯一入口，`bin/md-bundle.py` 掃全 repo 的 md 打包成 `content.js` → [site](site.md) | ① **Janet 寫 md→html 產生器**（`bin/md2html-*.janet`，已寫了五支半成品後放棄）：Janet 沒有堪用的 markdown 函式庫，等於要自己重寫一個 parser，而且 Windows 使用者得先裝 Janet 才看得到網站。② **預產 html 鏡像**（每篇 md 各產一支 html）：檔數翻倍、導航要手寫或再寫一層產生器、md 與 html 兩份內容會漂移。選現在這套的四個理由：`file://` 直接開不用起伺服器、導航零手工（manifest 自動長）、Windows 只要 python、**內容單一格式（只有 md）** | Chrome 擋 `file://` 的 fetch，所以內容一定要打包成 JS（`content.js` 目前 981 KB／191 篇）。若哪天要真的架站（有伺服器可 fetch）或 `content.js` 大到載入卡頓，重看打包策略 |
| 2026-08-30 | 工作流模板走**非侵入式 `wf/`**，頂層只多 `AGENTS.md`／`CLAUDE.md`／`.claude/` | 標準佈局（`workflows/`、`INDEX.md`、`SESSION-LOG.md`… 全鋪在頂層）：本 repo 頂層已有 `docs/ examples/ html/ modules/ reference/ snippets/ test/ try/` 八個資料夾與三份 `FINDINGS`，再鋪一層會蓋掉「一眼看得出這是 Janet 遊樂場」。父 repo `langs` 也是這樣導的 | 頂層資料夾數量。少到剩三四個時可以考慮攤平 |
| 2026-08-30 | flavor 只裝 **dev ＋ teaching ＋ knowledge**，`study-site` 留著但 `publish` 標「尚未啟用」 | heartbeat（沒有定期任務，裝了空轉）、multi-agent（目前只有單線派子 agent，`Agent` 工具就夠）、research（材料只有官方文件與本機實測，不到 30 件）、ops（沒有伺服器要維運）| `html/` 若真的長成互動課程 → 啟用 `publish`；開始跨 session 多 agent 協作 → 補 multi-agent 包 |
| 2026-08-30 | `docs/` 的 51 支檔**維持平鋪**，不按分區拆子資料夾 | 拆子資料夾（`基礎/`、`主題/`、`spork/`）要改 **361 條連結**（內部 239＋指入 70＋指出 52），換來的只有 `ls` 好看；讀者實際靠索引與數字前綴導航，`24-時間與日期.md` 也比 `../日常/24-時間與日期.md` 好連好找 | 檔數再翻倍、或編號前綴不再足以分組時重看 |
| 2026-08-30 | 本 repo 的**表一律留 md，不抽 `.json`／`.csv` 資料檔** | 依 [data-files](common/data-files.md) 契約，>1 KB 的同質記錄表該抽成資料檔。但本 repo 的表全是**給人讀的教學內容**（`reference/spork/` 的函式對照、`docs/` 的取捨表），不是給 AI 查詢的 ledger；抽走就等於把教材變成要跑 `tabledb.py` 才讀得到的東西。`wf-lint` 的 `BIGLIST` 因此長期非 0（全 repo 31 筆、`wf/` 內 3 筆），是**已知且刻意**的 | 出現真正需要 CRUD／查詢的記錄表（例如自動產生的相容性矩陣）時，那一份走資料檔，本決定不適用於它 |
