# testing — 跑測試 / 驗證

[WORKFLOWS](../WORKFLOWS.md)｜[INDEX](../INDEX.md)

改完怎麼確認沒壞：有哪些驗證、各自的指令、哪些 agent 自己跑得了、哪些得交給使用者。

**何時用**：改完程式要驗、使用者說「跑測試」、重構前要記基準。
**何時不用**：環境還沒裝好、不知道指令哪來 → [dev-env](dev-env.md)；驗證紅了要查成因 → [investigation](investigation.md)。

## Done when

- 下表標「改完必跑」的列指令回傳 0。
- 「誰跑」是使用者的列，已在 [WAIT_USER](../WAIT_USER.md) 各留一行（寫明跑什麼、什麼算過）。

## 驗證表

| 驗證 | 指令 | 誰跑 |
|------|------|------|
| **程式碼**（改完必跑，也是 commit 前的完整驗證）| `jpm test` | agent |
| **文件連結與結構**（改 `.md` 後跑）| `bash wf/tools/wf-lint.sh --strict .` | agent |
| **教學文裡的程式碼**（改到 `docs/`／`reference/`／`examples/` 時）| `janet examples/<對應範例>.janet`，或把那段直接 `janet -e '…'` 跑一次 | agent |
| **Windows 11 上的行為** | PowerShell 裡 `jpm deps` → `jpm test`（見 [`docs/00b`](../../docs/00b-windows-vscode.md)）| 使用者 → [WAIT_USER](../WAIT_USER.md) |

`jpm test` 沒有快速／完整之分——它把 `test/` 底下每支 `.janet` 各用一個獨立行程跑一遍（目前 11 支，全離線、不打網路、不呼叫真模型），三秒內跑完，所以**一律跑全部**。

「誰跑」只有兩種值：**agent**（這台 Manjaro 跑得動）、**使用者 → WAIT_USER**（要實機、外部服務、帳號、付費、目視）。判不準就當後者。

## 離線可跑的子集：全部

本專案的測試原則是**一律離線**——要測 HTTP 就在同一個行程裡起假伺服器（`test/llm-http-server.janet`），不打真網路。所以在這台機器上**沒有跑不動的子集**，`jpm test` 就是全集。

只有兩類東西 agent 驗不了，都要記到 [WAIT_USER](../WAIT_USER.md)：

- **Windows 行為**——本機是 Manjaro，凡是宣稱「Windows 上會怎樣」的改動都要請使用者實機跑（跨機差異見 [dev-env](dev-env.md)）。
- **`html/` 速查表的外觀**——方框、亂碼、截斷、排版只有人眼看得出來。

⚠ 另一個容易誤判的：`test/pi-shell-cli.janet` 會印「pi 可用？／claude 可用？」，那**取決於這台機器 PATH 上有沒有那兩支 agent CLI**。它不是斷言、不會讓測試變紅，但在別台機器上輸出會不一樣——**別把那行輸出當成驗證結果**。

## 綠燈不等於有檢查

**一道檢查通過，可能是因為它根本沒在檢查。** 這不是假設：曾在一天內抓到四個恆真檢查——結構稽核、「鎖已釋放」的檢查指向已刪目錄、連結檢查器走到子 repo 指標就停、自製字元偵測。

**規則：新增或修改一道檢查時，要證明它能變紅。** 先餵一個**應該被擋**的輸入，確認 exit ≠ 0；再餵正確的輸入，確認 exit = 0。**沒做過這個雙向驗證的綠燈不算證據。**

兩個推論：檢查器的**涵蓋範圍要跟著結構走**——拆出子 repo、搬走目錄之後，回頭確認檢查器還看得到那些地方（見 [refactor/moving-things.md](refactor/moving-things.md)）；**靜態全過不等於畫面上是對的**，方框、亂碼、截斷、手感只有人眼看得出來，這類記到 [WAIT_USER](../WAIT_USER.md)，不要自己宣稱通過。

## 交接

- 綠燈後回 [feature-dev](feature-dev/README.md) 接完剩下的步驟（code map → 文檔 → commit）。
- 同一個紅燈第二次撞到 → [common/gotchas](common/gotchas.md)。
