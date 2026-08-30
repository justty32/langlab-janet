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
| 2026-08-30 | 工作流模板走**非侵入式 `wf/`**，頂層只多 `AGENTS.md`／`CLAUDE.md`／`.claude/` | 標準佈局（`workflows/`、`INDEX.md`、`SESSION-LOG.md`… 全鋪在頂層）：本 repo 頂層已有 `docs/ examples/ html/ modules/ reference/ snippets/ test/ try/` 八個資料夾與三份 `FINDINGS`，再鋪一層會蓋掉「一眼看得出這是 Janet 遊樂場」。父 repo `langs` 也是這樣導的 | 頂層資料夾數量。少到剩三四個時可以考慮攤平 |
| 2026-08-30 | flavor 只裝 **dev ＋ teaching ＋ knowledge**，`study-site` 留著但 `publish` 標「尚未啟用」 | heartbeat（沒有定期任務，裝了空轉）、multi-agent（目前只有單線派子 agent，`Agent` 工具就夠）、research（材料只有官方文件與本機實測，不到 30 件）、ops（沒有伺服器要維運）| `html/` 若真的長成互動課程 → 啟用 `publish`；開始跨 session 多 agent 協作 → 補 multi-agent 包 |
| 2026-08-30 | `docs/` 的 51 支檔**維持平鋪**，不按分區拆子資料夾 | 拆子資料夾（`基礎/`、`主題/`、`spork/`）要改 **361 條連結**（內部 239＋指入 70＋指出 52），換來的只有 `ls` 好看；讀者實際靠索引與數字前綴導航，`24-時間與日期.md` 也比 `../日常/24-時間與日期.md` 好連好找 | 檔數再翻倍、或編號前綴不再足以分組時重看 |
| 2026-08-30 | 本 repo 的**表一律留 md，不抽 `.json`／`.csv` 資料檔** | 依 [data-files](common/data-files.md) 契約，>1 KB 的同質記錄表該抽成資料檔。但本 repo 的表全是**給人讀的教學內容**（`reference/spork/` 的函式對照、`docs/` 的取捨表），不是給 AI 查詢的 ledger；抽走就等於把教材變成要跑 `tabledb.py` 才讀得到的東西。`wf-lint` 的 `BIGLIST` 因此長期非 0（全 repo 31 筆、`wf/` 內 3 筆），是**已知且刻意**的 | 出現真正需要 CRUD／查詢的記錄表（例如自動產生的相容性矩陣）時，那一份走資料檔，本決定不適用於它 |
