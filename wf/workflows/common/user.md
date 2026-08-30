# user — 使用者偏好與確認邊界

[common/README](README.md)

agent 不用重猜的事。always-on 鐵律在 AGENTS.md，這裡是**這位使用者**的偏好——改了改這裡，不改鐵律。

| 項目 | 設定 |
|------|------|
| 語言 | **繁體中文**——回覆、文件、程式碼註解全部繁中；程式碼識別子、shell 指令、技術名詞（`fiber`、`marshal`、PEG…）保留原文 |
| 分支慣例 | 直接 commit `main`，不開 branch、不走 PR |
| 直接做、不用問 | 改文件、加／改教學與 reference、加測試、跑唯讀指令、`jpm test`、commit 到 `main`、把簡單機械性工作派給 sonnet 子 agent |
| 一定先問 | `git push`（本 repo 是 submodule，push 還牽動父 repo `langs` 的指標）、刪檔、開一塊全新的內容（新主題／新資料夾）|
| 回覆風格 | 短、先結論、再給理由；不要每段都 bullet。使用者問「要不要」時附**可執行判準**（門檻數字）與後果，讓他能改數字——例如「拆這層要改 361 條連結，換來的只有 `ls` 好看」這種量出來的代價 |
| 時區 | Asia/Taipei |

領域詞彙常猜錯 → 開 `glossary.md`（見 [common/README](README.md)）。
