# INDEX — janet-lab 專案地圖

janet-lab = **Janet 語言的遊樂場**：一個真的跑得起來的 jpm 專案（Janet 1.41.2 ＋ spork），外加一整套繁體中文的教學／速查／可抄片段／小模組。本檔只描述**頂層**：每列一句話＋連結；目錄內部複雜就放它自己的 README / INDEX。

## Repo 佈局

### 產物（真正的內容在這裡）

| 路徑 | 內容 |
|------|------|
| [`docs/`](../docs/README.md) | **分篇教學**（00–31，含 b/c/d 分身）——目的是**讓人掌握概念**。基礎篇 00–06 依序讀，18–26b 是日常會用到的，07–17 主題篇與 27–31 spork 篇需要時再翻（另一份索引：[主題與 spork 索引](../docs/主題與-spork-索引.md)）|
| [`reference/`](../reference/README.md) | **查「有哪些可用」**——內建的從 `root-env` 逐一列舉求全，[`reference/spork/`](../reference/spork/README.md) 只收常用（最全的在[官方](https://github.com/janet-lang/spork)）|
| [`html/`](../html/index.html) | 手寫的**六頁靜態速查表**（index / data-io / peg / concurrency / ffi / env），瀏覽器開檔即看。**唯一不受檔案大小慣例約束的目錄** |
| [`examples/`](../examples/README.md) | **教學附件**：配合 `docs/` 某一篇的可跑範例（`janet examples/x.janet`）|
| [`snippets/`](../snippets/README.md) | **做事的起點**：「我要做 X，抄哪段」的可貼可改片段 |
| [`modules/`](../modules/README.md) | 真的拿來用的小模組：`llm-http`（純 Janet 打 OpenAI 相容 proxy，含多輪 tool loop）、`pi-shell`（把非互動 agent CLI 包成子行程）|
| `bin/`、`janet-lab/`、`test/` | CLI 進入點（`bin/main.janet`，argparse 實例）、核心模組（`janet-lab/init.janet`）、測試（11 支，全離線）|
| `try/` | 一次性的試作區，從零寫一個 LLM 客戶端的過程 |
| `build/` | `jpm build` 的產物（三個執行檔，`:install false`）|

### 實測筆記

| 檔案 | 內容 |
|------|------|
| [`FINDINGS.md`](../FINDINGS.md) | 環境與架構的實測結論（LLM 供應商、為什麼走 litellm proxy）|
| [`FINDINGS-踩坑.md`](../FINDINGS-踩坑.md) | 被 LLM API／模組設計咬到的地方（七～十）|
| [`FINDINGS-踩坑b-工具鏈.md`](../FINDINGS-踩坑b-工具鏈.md) | jpm 與 import 的坑（十一～十三）|

> 這三份是**歷史性的實測紀錄**（有編號、會累積）；工作流層新踩到的坑記 [workflows/common/gotchas.md](workflows/common/gotchas.md)，兩邊不互相搬。

### 工作流（本層）

| 路徑 | 內容 |
|------|------|
| `workflows/` | 工作流（派發見 [WORKFLOWS.md](WORKFLOWS.md)；共享區 [workflows/common/](workflows/common/README.md)）|
| `../.claude/commands/` | slash 指令適配層（可選）。Claude Code 只讀專案根的這層，非侵入式佈局也留在根；沒有 slash 機制的工具忽略本目錄，直接跑 `tools/wf-lint.sh` |
| `tools/` | kernel 工具：`wf-lint.sh`（檢查）、`tabledb.py`（資料檔 CRUD／連結）、`find_big_lists.py`、`fix_moved_links.py`；資料檔契約見 [workflows/common/data-files.md](workflows/common/data-files.md) |

## 頂層文件

| 檔案 | 角色 |
|------|------|
| [`../AGENTS.md`](../AGENTS.md) | 最頂層路由器＋鐵律（中立入口；`../CLAUDE.md` 只是轉址）|
| [`../README.md`](../README.md) | **給人讀的**入口：馬上試、三個入口、結構、涵蓋範圍 |
| [WORKFLOWS.md](WORKFLOWS.md) | 派發器：意圖 → 工作流入口 |
| [STRUCTURE.md](STRUCTURE.md) | 結構整理參考（被動）：分層、膨脹即拆、四級成長、archive、工作流形式 |
| [SESSION-LOG.md](SESSION-LOG.md) | 我的 open 進度 |
| [WAIT_USER.md](WAIT_USER.md) | 等使用者親自做 / 驗證的事 |

> `AGENTS.md` 給 agent 看、`README.md` 給人看，兩份都是入口但讀者不同——**別把其中一份的內容搬到另一份**。
