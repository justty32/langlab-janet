# dispatch — 怎麼派線、怎麼收線（多 agent 平行）

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

**派誰**在 [team-model](team-model.md)（角色三層、聰明度分級、選人六項判準）；
**本檔管怎麼派、怎麼收**：主 session 的位置、任務單長什麼樣、平行時怎麼不打架、收工怎麼整合。
兩份互相連結、不重述——要決定模型級別請去 team-model，要寫任務單請留在這裡。

**何時用**：一次要開三條以上的平行線；同一個工作樹有多個 agent 同時寫檔；一輪線做完要整合。
**何時不用**：一兩條線、範圍不重疊——直接派，收的時候自己看一眼就好；純查詢派個 Explore 就夠。

## Done when

- 使用者**勾選過**的那張「線／模型／做什麼／重要性」表存在（開工前給，不是做完才補）。
- 每條線的任務單都有五段：通用規矩／背景／任務／驗收／回報格式。
- 所有線收工後跑過一條**整合線**，且 `jpm test`、`bash wf/tools/wf-lint.sh --strict .`、
  `python3 bin/md-bundle.py --check` 三條全綠。
- 這一輪的 commit 已分主題切開（不是一顆大 commit），`git status` 乾淨。

## 一、主 session 只派線、不做事

使用者 2026-09-19 明說「主 session 盡量不要自己做事」（見 [decisions](decisions.md)、[common/user](common/user.md)）。
主 session 的四件事：盤點現況 → **出表給使用者勾** → 派線 → 收線整合。自己寫檔就是浪費它的 context。

開工前先給這張表，讓使用者刪掉不想做的、改順序：

| 線 | 模型 | 做什麼 | 重要性 |
|----|------|--------|--------|
| T1 | fable | <一句話範圍> | 高／中／低 |

模型欄照 [team-model](team-model.md)：**困難 → fable，普通 → opus，簡單 → sonnet**。
「重要性」是給使用者砍線用的——他會直接說「T4 不要」。

## 二、任務單的五段（每條線都一樣，不要省）

1. **通用規矩**——每條線都是冷啟動，這段要寫全：
   - 先讀 [AGENTS.md](../../AGENTS.md)，再讀跟它有關的 common（碰程式碼 → [common/conventions](common/conventions.md)＋[common/code-map](common/code-map.md)；寫給人讀的 → [common/writing](common/writing.md)）。
   - 繁體中文；檔案 ≤150 行且 ≤8192 bytes（`html/` 除外）。
   - **文件裡的輸出要實測貼回來**，不准推測。
   - **不要 commit、不要 push**——收線的是整合線。
   - **不要動共享索引檔**（`wf/INDEX.md`、`wf/WORKFLOWS.md`、`docs/README.md` 與各索引、`README.md`、`project.janet`）。
   - **只碰自己負責的那些檔**；看到不認識的新檔（別條線剛長出來的）**不要動、不要刪、不要「順手整理」**。
2. **背景**——這條線需要知道的來龍去脈，寫死在任務單裡，不要叫它自己去翻。
3. **任務**——逐條列，每條都指名檔案路徑。
4. **驗收**——可觀察的：指令回傳 0、某檔存在某段、表格填滿幾列。
5. **回報格式**——固定四項：
   - 改了哪些檔（路徑清單）；
   - **給索引檔的可貼列**（直接給 markdown 一行，整合者原樣貼進去，不用自己讀檔再編）；
   - 驗證指令與**實際輸出**；
   - 沒做到的與原因。

## 三、同一工作樹平行：檔案所有權分區

沒有 worktree 隔離時，靠**分區**避免衝突：每條線在任務單裡被指定一組檔案，**別人的檔一律不碰**。

| 檔案類別 | 誰負責 |
|----------|--------|
| 一條線專屬的內容檔（某幾篇 docs、某個模組） | 該線 |
| 共享索引（`wf/INDEX.md`、`wf/WORKFLOWS.md`、各 README 索引表） | **整合線**（各線只交「可貼列」）|
| `project.janet` | 整合線；真的要平行改就**約定區塊**（一條線只動自己模組的那個 `declare-source`）|
| `html/content.js` | 整合線最後統一跑一次 `python3 bin/md-bundle.py`（見 [site](site.md)）|

## 四、整合線（所有線收工後開的那一條）

一條獨立的線，職責四件，按序做：

1. **補索引**——把各線交回來的「可貼列」貼進共享索引檔，順一下順序與措辭。
2. **修跨線發現的既有問題**——各線回報裡「不是我負責但看到壞掉」的那些，在這裡一次修。
3. **跑全套驗證**——`jpm test`、`wf-lint --strict .`、`python3 bin/md-bundle.py && --check`（表在 [testing](testing.md)）。
4. **分主題 commit**——按主題切成幾顆，不是一顆大的；訊息繁中。push 一律先問（鐵律 2）。

## 五、被中止的線怎麼處理

使用者砍掉一條線時 **不要直接刪它的產出**。派一條 **sonnet** 去做「調查 ＋ 留紀錄」：
盤點那條線已經改了什麼、做到哪、值不值得留，結果寫進 [planning](planning.md) 的 roadmap 或
[SESSION-LOG](../SESSION-LOG.md) 一行 open。

⚠ **被砍的線可能其實已經做完了**（這一輪的 T3c 就是）。所以第一步永遠是 `git status` ＋ `git diff --stat` 盤點**實際檔案狀態**，不是看它最後一則訊息說到哪。

## 六、踩過的坑（都真的發生過）

- **`git add -A` 會把別條線的暫存刪除復原**：某條線刪了檔還沒 commit，另一條線 `git add -A` 就把刪除也 staged／或把它救回來。平行期間**只 `git add <明確路徑>`**。
- **兩條線同時改 `project.janet`** 會互相覆蓋：要嘛交給整合線，要嘛約定一線一區塊。
- **`/tmp` 之類全域狀態的斷言會被別條線干擾**：另一條線同時在跑測試，共用路徑的檔案就會對不起來。測試要用行程專屬的暫存路徑（本專案的測試本來就全離線，見 [testing](testing.md)）。
- **冷啟動的線會「順手整理」別人的新檔**：所以通用規矩裡那句「看到不認識的新檔不動」一定要寫。

## 交接

- 選模型、算時程、管下級 context → [team-model](team-model.md)。
- 整合線的驗證表 → [testing](testing.md)；網站那一段 → [site](site.md)。
- 這一輪做不完、要跨 session 的 → [SESSION-LOG](../SESSION-LOG.md) 一行 open；
  等使用者決定的 → [WAIT_USER](../WAIT_USER.md)；為什麼這樣派 → [decisions](decisions.md)。
