# dev-env — 開發環境、指令、外部工具

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

這台機器上要能開發需要什麼、怎麼裝、跑什麼指令；外部工具設定與 env var 也收在這裡。

**何時用**：fresh clone、換機器、裝不起來、忘了指令、要加一個外部工具或環境變數。
**何時不用**：驗證 / 測試怎麼跑 → [testing](testing.md)；程式碼慣例 → [common/conventions](common/conventions.md)。

## Done when

- 照「流程（fresh clone 後）」走完，`jpm test` 回傳 0。
- 下面三張表沒有空欄；要使用者親自做的（帳號、授權、金鑰）在 [WAIT_USER](../WAIT_USER.md) 各佔一行。

## 流程（fresh clone 後）

1. 確認 `janet` 與 `jpm` 在 PATH：`janet -v` 應印 `1.41.2`。沒有的話照 [`docs/00-環境與工具鏈.md`](../../docs/00-環境與工具鏈.md) 從原始碼編進 `~/.local`（不用 sudo）。
2. `jpm deps` —— 下載並編 `project.janet` 宣告的依賴（目前只有 `spork`），裝進 `~/.local/lib/janet/`。
3. env var **不必設**：下面那張表的兩個都有預設值，只有 `modules/llm-http` 真的要打 LLM 時才需要。
4. `jpm test` —— 冒煙兼驗證，全綠才算裝好。

## 指令表

| 做什麼 | 指令 | 備註 |
|--------|------|------|
| 安裝依賴 | `jpm deps` | 只在 fresh clone、或改了 `project.janet` 的 `:dependencies` 後要重跑 |
| build | `jpm build` | 產出 `build/janet-lab`、`build/llm-http`、`build/pi-shell` 三個執行檔（都 `:install false`，不裝到系統）|
| 跑起來 | `janet bin/main.janet --help` | 沒有伺服器也沒有 port；進入點就是 `bin/main.janet`（argparse 實例）|
| 開 REPL | `janet` | `(quit)` 或 Ctrl-D 離開 |
| lint / format | —— | **Janet 沒有官方 formatter 或 linter**。診斷靠編輯器裡的 `janet-lsp`（0.0.12），格式靠 parinfer 顧括號。所以「lint 綠燈」不是本專案的驗收條件，`jpm test` 才是 |

驗證與測試指令不列這裡——連同「誰跑」一起在 [testing](testing.md)。

## 跨機差異

本專案在兩台機器上都實測跑過，**Windows 那台的坑多到自成一篇教學**：

| 環境 | 能跑 | 跑不了的 → 怎麼辦 |
|------|------|------------------|
| **Manjaro**（主力機，`~/.local` 原始碼編譯） | 全部：`jpm deps` / `jpm test` / `jpm build` / native 模組 | — |
| **Windows 11 + VS Code**（`%LOCALAPPDATA%\Apps\Janet`）| 全部，但要先做兩件事：把 `jpm` 的 `default-config.janet` 從 MSVC 改成 mingw、且 `jpm deps` **必須在 PowerShell 跑**（git-bash 下 jpm 呼叫 `git submodule` 會炸）| 完整過程與五個坑見 [`docs/00b-windows-vscode.md`](../../docs/00b-windows-vscode.md)。**agent 在這台 Manjaro 上驗不了 Windows 行為**——凡是宣稱「Windows 上會怎樣」的改動，都要在 [WAIT_USER](../WAIT_USER.md) 記一行請使用者實機跑 |

## 外部工具與 env var

| 名稱 | 用途 | 怎麼取得 / 設定 |
|------|------|----------------|
| `spork` | 官方準標準庫（json / argparse / test / path…），教學與模組大量用到 | `jpm deps` 自動裝到 `~/.local/lib/janet/spork/`；**不要** `(import spork)`，那會把 700 個 binding 灌進 env（見 [`docs/27-spork-全覽.md`](../../docs/27-spork-全覽.md)）|
| `janet-lsp` | 編輯器內的診斷與跳定義 | `~/.local/bin/janet-lsp`（0.0.12）；可選，不影響 `jpm test` |
| `LITELLM_BASE` | `modules/llm-http` 要打的 proxy 位址 | 只有真的要打 LLM 時才設。不設就用 `defaults.janet` 的 `http://127.0.0.1:4000`（⚠ 一定寫 `127.0.0.1` 不要寫 `localhost`，原因見該檔註解）|
| `LITELLM_API_KEY` | 送給 proxy 的 Bearer token | 不設就用 `"dummy"`（proxy 沒設 master key 時收）。**真金鑰不進 repo**，設在 shell 或 `~/.config/` 的 endpoint 設定檔 |

需要帳號、付費、授權才能取得的：守鐵律 2（授權來源），並在 [WAIT_USER](../WAIT_USER.md) 記一行。

> **測試一律離線**：`jpm test` 不打網路、不呼叫真模型，所以上面那兩個 env var 沒設也全綠。要測 HTTP 就在同一個行程裡起假伺服器（見 `test/llm-http-server.janet`）。

## 交接

- 環境就緒要開工 → [feature-dev](feature-dev/README.md)；先確認驗證跑得動 → [testing](testing.md)。
- 同一個裝機坑第二次撞到 → [common/gotchas](common/gotchas.md)。
