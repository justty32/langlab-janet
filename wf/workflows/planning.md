# planning — 想法成熟管線（idea → roadmap → 詳規 → 執行）

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

從萌芽到動工的四階段收在**同一條管線**，不拆成四個工作流——免得卡在「這算 idea 還是 roadmap」。

**何時用**：使用者說「記個想法」「以後要做」「排進 roadmap」「幫我規劃」。
**何時不用**：三兩步的小事直接做；已有 spec / plan 且在動工 → 執行工作流；只是要調查清楚 → investigation（dev 包）。

## Done when

- idea / roadmap：對應表多一列，或既有列狀態欄更新。
- 詳規：spec 有「方案 / 取捨」段、plan 有「步驟 / 驗證」段；動工完成後移 `archive/`。

## 階段

| 階段 | 回答的問題 | 落點 |
|------|-----------|------|
| **idea** | 要不要做？ | 下方「想法」表 |
| **roadmap** | 會做，何時？ | 下方「roadmap」表 |
| **詳規** | 怎麼做？ | 開發：**spec**（方案）→ **plan**（動工前詳規），各一檔放 `planning/specs/`、`planning/plans/`，第一份出現時升級成資料夾型。非開發：接 plan-a-thing（knowledge 包）|
| **執行** | — | 開發：feature-dev；非開發：plan-a-thing 的執行段 |

## 想法（要不要做）

| 想法 | 一句話 | 狀態（想想 / 會做→搬 roadmap / 不做＋原因）|
|------|--------|------------------------------------------|

## roadmap（會做，何時）

> 下面兩列是 2026-09-19 因 token 消耗被中途砍掉的半成品（S2 事後盤點留檔，見各檔 ⚠ 注記）。
> 第三列 `bin/md2html*`（純 Janet 的 md→html 鏡像）已結案：使用者改決定「md 不動、做瀏覽器閱讀器」，改用 Python 打包＋前端渲染做完（`bin/md-bundle.py` ＋ `html/reader/`），五支 Janet 半成品已刪。
> 另外兩列（`docs/47*` agent 教學、`reference/spork/infix`）當時只差掛索引，整合線已補完並結案。

| 事項 | 何時 / 順序 | 前提 |
|------|------------|---------|
| `reference` 補洞：peg／file-net／marshal-image-env／debug 全表 | 待續 | 做到：`peg-全表.md`＋`peg-全表b-捕獲.md`（PEG 函式 6＋比對 21＋捕獲 21，全核過）、`file-與-net.md`（`file/*`＋`stdin/stdout/stderr`＋印讀家族共 31 個，完整，已加 ⚠）。三篇**已由整合線掛進 `reference/README-內建全表.md`**（索引表因超標拆成入口＋全表兩檔）。剩下：`net/*` 19 個的 `file-與-netb-socket.md`（規劃過沒寫）、`marshal-image-與-env.md`、`debug-全表.md` 完全沒開始。當初做的 root-env 覆蓋率盤點沒有落地，要重算（腳本見 `reference/README.md`）。接手先看 `reference/README-內建全表.md`「並行、IO、系統」那一區。 |
| 全 repo 體檢：巡一輪抓事實性錯誤 | 待續，範圍未知 | 已做：巡到 `README.md`／`examples/README.md`／`try/README.md`／`html/gotchas.html`／`reference/README.md`／`reference/math-數學與隨機.md`／`reference/字串與-buffer.md`／`docs/23b`／`docs/27`／`docs/主題與-spork-索引.md`／`docs/怎麼做-X.md`／`docs/語言細節索引.md`／`docs/路線圖.md`，修掉幾處過時數字（spork 706→707 個綁定、`math/nan?` 應為 `nan?`）跟寫死的計數改成通用說法。途中把 `reference/README.md` 的 root-env 綁定數改成 702，S2 又修回 703；整合線第三次實測（`janet`、`janet -e`、REPL 三種跑法都試）**是 702**（另有 5 個 keyword 鍵不是綁定），已照 702 定案並在該檔寫明怎麼算。剩下：不知道巡到哪就被中止，`docs/`／`reference/`／`modules/`／`examples/` 還有沒巡完的部分不明。接手先看上面列的檔案清單回推巡到哪，再往下巡。 |

## 交接

- 決定「為什麼選 A 不選 B」 → [decisions](decisions.md)。卡在使用者 → [WAIT_USER](../WAIT_USER.md) 一行；跨 session → [SESSION-LOG](../SESSION-LOG.md) 一行。
