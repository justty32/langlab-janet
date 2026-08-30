# info-map — 材料導航 index（哪份材料在哪、負責什麼）

[common/README](README.md)｜[INDEX](../../INDEX.md)

碰材料前先查這張表，只讀相關那幾份；動完再照維護鏈把表更新回去。與開發 flavor 的 code map **刻意對稱**：code map 描述程式碼結構，info-map 描述材料結構。碰材料的工作流（[digest](../digest.md) / [learn](../learn.md) / [organize](../organize.md) / [write](../write.md)）共用。

## 材料表

| 材料 | 位置 | 負責什麼 | 衍生產物 |
|------|------|---------|---------|
| Janet 官方文件 | https://janet-lang.org/docs/index.html | 語言本身怎麼寫、內建函式有哪些 | `docs/`（教學）與 `reference/`（查全表）|
| Janet 內建 API 索引 | https://janet-lang.org/api/index.html | 某個內建函式的簽名與語意 | `reference/` |
| spork 官方 repo | https://github.com/janet-lang/spork | spork 各模組有什麼、怎麼用 | `docs/27`–`31`（spork 五篇）與 `reference/spork/` |
| 本機實測（`janet -e` 直接跑）| 這台機器 | 文件沒寫／寫得不清楚的實際行為是什麼 | 對應的 `docs/` 篇章與 `FINDINGS-踩坑*.md` |

## 維護鏈：材料 > info-map > 衍生產物

**優先級**（衝突或時間不夠時，依序保持一致）：材料 > info-map > 衍生產物（摘要、筆記、文章）。
**info-map 與材料衝突時以材料為準，立刻改 info-map。**

1. **動手前**：先讀本表找到相關材料，只讀清單裡的那幾份——不要整個資料夾翻。
2. **動手後**：新增／刪除了材料，或某份材料的職責顯著改變，必須同步更新本表。
3. 材料檔裡**不加**「對應 info-map」的註記（維護成本過高）；反向查找直接 grep 本檔。
4. 一輪 digest / learn 期間本表可暫時落後，**收尾前必須對齊**。
