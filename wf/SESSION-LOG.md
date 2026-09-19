# SESSION-LOG — 進度（只列 open）

[INDEX](INDEX.md)｜等使用者的另記 [WAIT_USER](WAIT_USER.md)

**寫入時機**：
1. **開始**多步驟工作前先寫一行 open（不是做完才寫）；硬中斷時本檔才有「進行中」。
2. **每次 commit 後**更新或刪除該行。
3. 條目格式：`- [工作流] 一句 open 狀態 → 下一步 / 連結`；完成即刪，歷史交給 git log，決策落到 [workflows/decisions.md](workflows/decisions.md)。

> 膨脹就拆：過大就開 `session_logs/` 按工作流拆檔＋index（照 [STRUCTURE](STRUCTURE.md)）。

## 最新進度

- [planning] `bin/md2html*`（T4 md→html 產生器）中途砍線，四支模組完整、`render.janet` 編不過 → [planning roadmap](workflows/planning.md#roadmap會做何時)
- [planning] `reference` 補洞（R1）：peg 兩篇＋`file-與-net.md` 已掛索引，`file-與-net.md` 的 `net/*` 半篇、`marshal-image-與-env.md`、`debug-全表.md` 未開始 → [planning roadmap](workflows/planning.md#roadmap會做何時)
- [planning] 全 repo 體檢（T5）中途砍線，巡到一半範圍不明（root-env 綁定數已定案 702）→ [planning roadmap](workflows/planning.md#roadmap會做何時)

## 各工作流 session-log

| 工作流 | session-log | open 摘要 |
|--------|-------------|----------|
