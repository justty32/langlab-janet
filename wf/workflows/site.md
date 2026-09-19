# site — 網站／閱讀器維護：md 進得去、畫面沒壞

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

本 repo 的「網站」就是 [`html/index.html`](../../html/index.html) 這支閱讀器：**內容全部是 md**，
`bin/md-bundle.py` 把 repo 裡 191 支 md 打包成 `html/content.js`，首頁路線卡片以外的導航
（分區清單、側欄樹、全文搜尋、上一頁／下一頁）**全由 manifest 自動長出來，零手工**。
本工作流管的是：改完 md 之後怎麼讓它出現在網站上、怎麼改閱讀器本身、怎麼驗收。

**何時用**：新增／改動任何 `.md` 之後；要改閱讀器外觀或行為；要加首頁路線卡片；要加一頁速查表；要升 `marked`。
**何時不用**：只是寫 md 內容本身（文風走 [common/writing](common/writing.md)，教學結構走 docs 自己的索引）；
要跑全套測試 → [testing](testing.md)；要動 `bin/md-bundle.py` 的邏輯（那是改程式，走 [feature-dev](feature-dev/README.md)，回來這裡驗收）。

## Done when

- `python3 bin/md-bundle.py --check` exit 0（0 條 `BROKEN-LINK`／`BROKEN-ANCHOR`）。
- `jpm test` 綠、`bash wf/tools/wf-lint.sh --strict .` 的 `broken=0`。
- `git status` 裡 `html/content.js` 已跟著這次的 md 一起進 commit（不是留在工作樹）。
- 改了外觀／行為時：headless 截圖至少四張（首頁、一篇 docs、一頁速查表、`?theme=dark`）都看過，
  人眼確認的那關寫進 [WAIT_USER](../WAIT_USER.md)。

## 流程

### A. 只是新增／改了 md（最常見）

1. 改 md。
2. `python3 bin/md-bundle.py`（＝`jpm run bundle`）重打包 `html/content.js`。
3. `python3 bin/md-bundle.py --check` 掃全部 md 的相對連結與 `#錨點`，壞的一條一行、exit 1。
   它跟 `wf-lint` 互補：**`wf-lint` 不掃 `reference/`**，`--check` 掃；`--check` 另外會驗
   `html/app.js` 裡 `HOME_CARDS` 的每個 `md:` 路徑真的存在。
4. commit 時把 `html/content.js` **一起**進去（產物進 git，因為使用者要 `file://` 直接開，不能要求他跑打包）。

⚠ **不要手改任何導航**：首頁分區清單、側欄、搜尋索引都是 manifest 產生的。
唯一手寫的導航是 `HOME_CARDS`（見 C）。

### B. 加一頁速查表

在 [`cheatsheets/`](../../cheatsheets/README.md) 開一支新 md 就好——閱讀器看到 `section == cheatsheets`
會自動套 `.cheat` 兩欄卡片版型（`html/style.css`），不必改 JS。然後：
在 [`cheatsheets/README.md`](../../cheatsheets/README.md) 的頁表加一列 → 跑 A 的第 2–4 步。
內容規矩照鐵律 4（≤150 行、≤8192 bytes）與鐵律 5（程式碼都要真的跑過）。

### C. 加／改首頁路線卡片

改 `html/app.js` 頂部的 `HOME_CARDS`（檔案開頭數得出來的那個陣列），每筆三欄：
`md`（路徑）、`title`、`blurb`。**這是整個網站唯一允許手寫的導航**，所以只放「路線級」的入口，
一般篇目交給 manifest。加完跑 `--check`，它會驗路徑存在。

### D. 改外觀／行為

| 要改什麼 | 改哪裡 |
|----------|--------|
| 顏色、字級、版型、兩欄卡片 | `html/style.css`——色票 token **兩套**（`:root` 亮、`@media (prefers-color-scheme:dark)` 內 `:root:not([data-theme="light"])` 暗、再加 `:root[data-theme="dark"]` 手動覆蓋）。**改 token 要三處一起改**，不要只改亮的 |
| 路由、搜尋、目錄樹、Janet 上色、錨點 slug | `html/app.js` |
| 外框（header／aside／main 骨架） | `html/index.html`（很薄，通常不用動）|

⚠ `app.js` 的 `slugify` 必須跟 `wf/tools/check_anchors.py` 的 `github_heading_slug` 同一套規則——
動了其中一邊，另一邊要同步，否則 md 裡既有的 `#錨點` 連結會跳不到而 `--check` 也抓不出來。

### E. 升級 `vendor/marked.min.js`

現況 v15.0.12（MIT），從 `https://cdn.jsdelivr.net/npm/marked@<版本>/marked.min.js` 抓，
**整支換掉**即可（本 repo 只在檔頭多加一行出處註解，其餘沒改過；換完記得把那行補回去）。
換完一定重截圖：marked 大版本改過 token 行為，表格、巢狀清單、fenced code 最容易壞。

## 驗收：headless 截圖（外觀唯一能自動看的一關）

`file://` 直接開，不用起伺服器（閱讀器就是為了這件事才打包 content.js）：

```sh
R=/home/lorkhan/repo/langs/janet-lab/html/index.html; O=/tmp/shot   # O 換成你的暫存目錄
google-chrome-stable --headless=new --disable-gpu --window-size=1280,900 \
  --screenshot=$O/home.png  "file://$R"                               # 首頁
google-chrome-stable --headless=new --disable-gpu --window-size=1280,900 \
  --screenshot=$O/docs.png  "file://$R#docs/01-語言速成.md"            # 一篇 docs（hash 路由）
google-chrome-stable --headless=new --disable-gpu --window-size=1280,1400 \
  --screenshot=$O/cheat.png "file://$R#cheatsheets/核心.md"            # 兩欄卡片版型
google-chrome-stable --headless=new --disable-gpu --window-size=1280,900 \
  --screenshot=$O/dark.png  "file://$R?theme=dark#docs/README.md"     # 暗色（?theme=dark 強制）
google-chrome-stable --headless=new --disable-gpu --window-size=1280,900 \
  --screenshot=$O/q.png     "file://$R?q=peg"                          # 搜尋結果（?q=詞）
google-chrome-stable --headless=new --disable-gpu --window-size=420,900 \
  --screenshot=$O/mobile.png "file://$R"                               # 窄螢幕：側欄要收成 ☰
```

`?theme=dark`／`?q=詞` 這兩個 query 參數就是為了 headless 驗證才留的（見 `app.js` 該兩行的註解）。
截完**要真的打開來看**：方框、亂碼、截斷、卡片沒對齊都只有人眼看得出來。
⚠ 截圖輸出的 `ERROR:components/dbus/...Request ended` 是 headless 的雜訊，看到 `N bytes written` 就是成功。

## 交接

- **外觀只有人眼看得出來的部分**（手感、捲動、字重、窄螢幕操作）→ 在 [WAIT_USER](../WAIT_USER.md) 留一行請使用者開 `html/index.html` 看，寫明看什麼、什麼算過。
  理由見 [testing](testing.md) 的「綠燈不等於有檢查」。
- **Windows 使用者只要 python**：打包不需要 Janet、不需要 node；`html/` 是純靜態、`file://` 開檔即看。
  這是當初選這套架構的主因之一，見 [decisions](decisions.md)。
- 驗證指令的完整表在 [testing](testing.md)；程式碼慣例（含「新增／改動 `.md`」那一列）在 [common/conventions](common/conventions.md)。
- `html/` 是**唯一不受檔案大小慣例約束**的目錄（鐵律 4），但別把內容寫進 `html/`——內容一律是 md。
