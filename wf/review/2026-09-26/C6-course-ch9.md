# C6 course 第 9 章（import／jpm／測試）審閱

審閱者：fable｜日期 2026-09-26｜範圖：`course/9-1-import-與拆檔.md`、`course/9-1b-import-的規則與坑.md`、`course/9-2-jpm-專案.md`、`course/9-2b-jpm-專案.md`、`course/9-2c-jpm-專案.md`、`course/9-3-寫測試.md`、`course/9-3b-測試配方與-spork-test.md`、`course/9-3c-選哪套與會踩的坑.md`、`examples/course/9-1.janet`、`examples/course/9-2.janet`、`examples/course/9-3.janet`、`examples/course/9-1-lib/`、`examples/course/9-demo/`

## 總評
八篇＋三支範例＋示範專案全部實跑過，文中貼的輸出（import 錯誤訊息、`jpm test`／`rule-tree`／`rules`、build 不重編、`jpm new` 結束碼 0、spork/test 失敗格式、`\xE4` 逃逸、skip-asserts 變紅）逐條與 Janet 1.41.2 一致，範例檔 exit 0。品質高，錯誤少。最值得先修的一件：9-1／9-1b 對 import 路徑規則講得太窄，「`/` 開頭會被吃掉」其實是 Janet 的「相對專案根（cwd）」語法、「`init.janet` 不給 `:as` 會得到 `init/`」也只在寫出 `/init` 時才成立；讀者照學會得出錯誤的心智模型。其次是 9-1b 承諾「`use` 帶進 `main` 的坑留到 9-2 講」，9-2 三篇完全沒講。9-2 拆成三支順序自然（概念→指令→坑），只是檔名沒跟其他 b/c 篇一樣描述內容。測試章節與 `docs/23`、`docs/23b` 沒有矛盾；反而是 `docs/23b:56` 說 `capture-stdout` 回 buffer，實測是 string，course 寫對、docs 寫錯。

## 發現
- [中][錯誤] `course/9-1b-import-的規則與坑.md:85` — 「import 只認得 `./`、`../` 開頭的相對路徑，和系統模組路徑」不完整：`module/paths` 還有 `.:all:.janet`（`/x` 開頭＝相對 cwd／專案根）與 `:@all:`（`@x` 開頭＝相對 dyn）；在 9-demo 裡 `janet -e '(import /demo/init)'` 成功載入。 — 把 79–85 行的「絕對路徑會被吃掉」改成「`/` 開頭是 Janet 的『相對專案根目錄』語法，不是絕對路徑」，再說要絕對路徑用 `dofile`。 — [實測]
- [中][錯誤] `course/9-1-import-與拆檔.md:58` — 「很多模組入口檔叫 `init.janet`，不給 `:as` 會得到一堆 `init/ask`」只在寫 `(import ./foo/init)` 時成立；寫 `(import ./foo)` Janet 會自動找 `foo/init.janet`，前綴是 `foo/`（9-demo 裡 `(import ./demo) (demo/add 1 2)` → 3）。 — 補一句「`(import ./demo)` 會自動找 `demo/init.janet`，前綴就是 `demo/`」，並讓 `bin/main.janet`、測試檔的 `(import ../demo/init :as demo)` 改成 `(import ../demo)` 或說明為何寫全。 — [實測]
- [中][結構] `course/9-1b-import-的規則與坑.md:57` — 「會把模組自己的 `main` 也帶進來，這個坑留到 9-2 講」，`grep use course/9-2*.md` 零命中，9-2 三篇沒有這個坑。 — 在 9-2c 補一條「`use` 了帶 `main` 的檔」的坑，或把這句刪掉。 — [實測]
- [中][難懂] `course/9-2-jpm-專案.md:107` — 剛在 9-1 學到「`./` 相對寫這行的那支檔」，這裡卻在 `janet -e` 裡寫 `(import ./examples/course/9-2)`，相對的是 cwd，沒有一句解釋。 — 加註「`-e` 沒有『目前檔案』，`./` 就退回相對目前目錄」。 — [實測]
- [低][錯誤] `course/9-1-import-與拆檔.md:117` — 「多寫 `.janet` 也載得到」是真的，但前綴會變成 `greet.janet/`，不加 `:as` 幾乎不能用（`(greet/hello)` → `unknown symbol`）。 — 補一句「載得到但前綴變成 `greet.janet/`，所以別這樣寫」。 — [實測]
- [低][範例] `course/9-2b-jpm-專案.md:39-44` — `jpm rule-tree` 實際印出全部 8 條 rule 的樹，文中只貼 `test` 那一段卻沒說是節錄。 — 在程式碼區塊前加「（只節錄 test 那段）」。 — [實測]
- [低][結構] `course/9-2b-jpm-專案.md:1`、`course/9-2c-jpm-專案.md:1` — 檔名 `9-2b-jpm-專案.md`／`9-2c-jpm-專案.md` 跟 H1「jpm 日常指令」「jpm 會咬人的地方」不符；同章 9-1b、9-3b、9-3c 檔名都描述內容。 — 改成 `9-2b-jpm-日常指令.md`、`9-2c-jpm-會咬人的地方.md`（連結一併改）。 — [實測]
- [低][結構] `course/9-1-import-與拆檔.md:1-3` — 9-1、9-2、9-3 三篇開頭都沒有「← 上一課」導航，只有 b/c 續篇有；讀者從 9-1b 回 9-1 後找不到 8-3。 — 比照 9-1b 第 3 行加 `[← 8-3 · 命令列參數]`。 — [實測]
- [低][難懂] `course/9-1-import-與拆檔.md:31` — 「`def-` … 等一下會講」但解釋在另一支檔 9-1b:39。 — 改成「9-1b 會講」。 — [實測]
- [低][範例] `course/9-2-jpm-專案.md:79` — 「別人寫 `(import demo/init)` 就能用」，其實 `(import demo)` 也行（`:sys:/:all:/init.janet`）；跟上面 `init.janet` 那條同源。 — 兩處一起講清楚 init.janet 的慣例。 — [疑]（沒 `jpm install` 實測，從 `module/paths` 推得）
- [低][錯誤] `docs/23b-用-spork-test-寫測試.md:56` — 跨篇對照發現：說 `capture-stdout` 回 `(nil @"被抓走了\n")`（buffer），實測是 `(nil "...\n")` string；course 9-3b:86 寫 string 是對的。 — 改 docs/23b。 — [實測]
- [低][文風] `course/9-3-寫測試.md:89` — 「依檔名排序」正確（jpm `declare.janet:298` 用 `(sort (os/dir dir))`），但 `dodir` 也會遞迴進子目錄，文中說「`test/` 底下每一支」容易讓人以為只看一層。 — 補「含子目錄」。 — [實測]

## 沒來得及看的
- `course/9-2c-jpm-專案.md:49-55` `:source` 給目錄多一層的說法沒實測（任務要求不 `jpm install`）。
- 9-2c 小練習 2 的 phony rule 解答（`examples/course/9-2.janet:15`）沒實跑。
- 簡體用字對照 `wf/workflows/common/writing/zh-tw.md` 沒逐字掃；目測未見。
