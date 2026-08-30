# investigation — 調查 / 解讀外部系統 / 可行性

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

只讀不改，查清楚「這怎麼運作／可不可行」，產出可歸檔的筆記。

**何時用**：看懂外部系統或別人的碼、評估可行性、查 bug 成因。
**何時不用**：已知道怎麼改 → [feature-dev](feature-dev/README.md)；只搬結構 → [refactor](refactor/README.md)。

## Done when

- 筆記落在 repo 根的 **`FINDINGS*.md`**：環境與架構結論進 [`FINDINGS.md`](../../FINDINGS.md)、被 API／模組設計咬到的進 [`FINDINGS-踩坑.md`](../../FINDINGS-踩坑.md)、jpm 與 import 的工具鏈坑進 [`FINDINGS-踩坑b-工具鏈.md`](../../FINDINGS-踩坑b-工具鏈.md)；**一則一個編號、只追加**，且下列五段非空。
- 那三份任一超過 150 行或 8192 bytes → 按語意拆成 `FINDINGS-<主題>.md`，原檔名留當入口（見 [STRUCTURE](../STRUCTURE.md)）；`FINDINGS.md` 的索引要同步（它曾經漏列過第十二、十三則）。
- 結論是「要動手」→ [planning](planning.md) 有接手列。

> **`FINDINGS*.md` 與 [common/gotchas](common/gotchas.md) 的分工**：`FINDINGS` 是**有編號、會累積、講清楚來龍去脈**的調查紀錄；`gotchas` 是**一條一行**的「第二次撞到就記一筆」。查一個現象先翻 gotchas，要理解為什麼才翻 FINDINGS。

## 流程

1. **收集事實**：只讀不改，一條一則，附出處。
2. **對照現有能力**：這件事現在能不能做、靠什麼做。
3. **分類**：可直接做／有缺口／不值得做／需使用者驗證。
4. **產出 finding**：照下方筆記模板寫成一份可歸檔的筆記；缺口進 [planning](planning.md)，踩到的坑進 [common/gotchas](common/gotchas.md)，需使用者驗證的進 [WAIT_USER](../WAIT_USER.md)。

**不把未驗證的猜測寫成結論**——不確定就寫「缺什麼證據」，不要補完。

## 筆記模板

- **問題**：要回答什麼，一句話。
- **方法**：讀了哪些檔、跑了什麼指令。
- **發現**：一條一則事實，附出處。
- **結論**：直接回答問題；不確定就寫缺什麼。
- **來源**：檔案路徑＋行號、指令輸出、連結。

## 交接

- 要動手 → [feature-dev](feature-dev/README.md)；同一坑第二次 → [common/gotchas](common/gotchas.md)。
