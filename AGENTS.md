# janet-lab — AI agent 專案備忘

janet-lab = **Janet 語言的遊樂場**：一個真的跑得起來的 jpm 專案（Janet 1.41.2 ＋ spork），外加一整套繁體中文的教學（`docs/`）、速查（`html/`）、查全表（`reference/`）、可抄片段（`snippets/`）與真的拿來用的小模組（`modules/`）。本檔是最頂層路由器，只指向下一層；細節不寫這裡（分層原則見 [STRUCTURE.md](wf/STRUCTURE.md)）。

> ⚠ **這是 git submodule**（獨立 repo：`justty32/langlab-janet`，掛在 `~/repo/langs` 底下）。
> 在這裡的改動要在**本層**commit／push；父 repo `langs` 那邊只記錄「指向哪個 commit」。

## 開場與入口

- 每個 session 先跑 `grep -c '^- \[' wf/SESSION-LOG.md wf/WAIT_USER.md`：非 0 才開 [SESSION-LOG.md](wf/SESSION-LOG.md)（進度）/ [WAIT_USER.md](wf/WAIT_USER.md)（等使用者）。
- **碰原始碼前**：慣例與 code map → [workflows/common/conventions.md](wf/workflows/common/conventions.md)、[workflows/common/code-map.md](wf/workflows/common/code-map.md)；環境與指令 → [workflows/dev-env.md](wf/workflows/dev-env.md)。
- **產出給人讀的東西前**（教學、reference、README）：文風 → [workflows/common/writing.md](wf/workflows/common/writing.md)。
- **要你動手做事** → [WORKFLOWS.md](wf/WORKFLOWS.md) 依意圖派發，再讀該工作流入口檔。
- **想看專案結構** → [INDEX.md](wf/INDEX.md)。
- 使用者偏好與邊界 → [workflows/common/user.md](wf/workflows/common/user.md)。

## 鐵律（always-on，隨時適用）

1. 重構 / 整理**不改原意**：碰程式碼＝行為不變且 `jpm test` 綠燈；碰教學文＝逐段對照原意核，照 `Done when:` 驗收。
2. **不可逆或對外的動作**（push、刪除、對外送出）要有**授權來源**：使用者當場確認，或他親自登記在清單裡。都沒有就先問。commit 到 `main` 是慣例，**push 一定先問**。
3. **所有回覆、註解、留檔用繁體中文**；程式碼識別子、shell 指令、技術名詞保留原文。
4. **檔案大小慣例**：`html/` 以外，每支檔案 **≤150 行且 ≤8192 bytes**；超標就按內容語意拆，原檔名保留當入口（例 `10` → `10b`／`10c`／`10d`）。
5. **文件裡寫的程式碼要真的跑過**：教學／reference 的每段輸出都是實測貼回來的，不是推測的。改動或新增前先跑一次。

> **具體流程**在各工作流入口檔，不在本檔。條列與表格的存放規矩（>1 KB 的機器讀表走資料檔、給人點的導航表留 md）見 [workflows/common/data-files.md](wf/workflows/common/data-files.md)——本 repo 目前的表全是給人讀的教學內容，一律留 md。

<!-- wf-kernel v0.5 (2026-08-30) -->
