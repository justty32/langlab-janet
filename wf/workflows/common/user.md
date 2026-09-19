# user — 使用者偏好與確認邊界

[common/README](README.md)

agent 不用重猜的事。always-on 鐵律在 AGENTS.md，這裡是**這位使用者**的偏好——改了改這裡，不改鐵律。

**何時用**：使用者說了偏好、講定了確認邊界（哪些事可以直接做、哪些一定先問）、或講定分支慣例／時區／語言時，記到這裡。
**何時不用**：一次性的小事不必記（例如「這次先不要跑測試」）——那是當下的指示，不是長期偏好；長期知識歸屬層的原則見 [STRUCTURE](../../STRUCTURE.md)。

## Done when

對應的那一列已更新（或新開一列），沒有留下與新偏好矛盾的舊值。

| 項目 | 設定 |
|------|------|
| 語言 | **繁體中文**——回覆、文件、註解全繁中；識別子、shell 指令、技術名詞保留原文（同鐵律 3）|
| 分支慣例 | 直接 commit `main`，不開 branch、不走 PR |
| 直接做、不用問 | 改文件、加／改教學與 reference、加測試、跑唯讀指令、`jpm test`、commit 到 `main`、派子 agent（分級見下）|
| 一定先問 | `git push`（submodule，牽動父 repo `langs` 的指標）、刪檔、開一塊全新的內容（新主題／新資料夾）|
| 回覆風格 | 通用風格見 [reply-style.md](reply-style.md)；這位使用者的例外：**不要每段都 bullet**。問「要不要」時附**可執行判準**（門檻數字）與後果，讓他能改數字 |
| 派工分級 | 可開**無限個 agent**，主 session 盡量不自己做事；難的派 **fable**、普通派 **opus**、簡單派 **sonnet**（2026-09-19 使用者原話）。判準見 [team-model](../team-model.md) |
| 時區 | Asia/Taipei |

領域詞彙常猜錯 → 開 `glossary.md`（見 [common/README](README.md)）。
