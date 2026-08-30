# `os/` ・ 全部 48 個

[← reference 索引](README.md)

對應教學：[39 跟作業系統打交道](../docs/39-跟作業系統打交道.md)、
[11 子行程](../docs/11-pipeline-signal.md)、[19b 檔案系統](../docs/19b-檔案系統與路徑.md)、
[12d 環境變數](../docs/12d-os-環境變數.md)。時間那組另有專頁：[os-時間.md](os-時間.md)。

> 對著 `root-env` 逐一核過，**48 個一個不漏**。簽名照 `(doc …)` 原文。

## 這台機器

| 函式 | 簽名 | 回什麼 |
|------|------|--------|
| `os/which` | `(os/which &opt test)` | `:linux` `:windows` `:macos` `:bsd`…**跨平台分歧點** |
| `os/arch` | `(os/arch)` | `:x64` `:arm64`… |
| `os/compiler` | `(os/compiler)` | 編這份 janet 的編譯器（`:gcc`／`:clang`／`:msvc`）|
| `os/cpu-count` | `(os/cpu-count &opt dflt)` | 核心數；決定並行度用 |
| `os/getpid` | `(os/getpid)` | 自己的 PID |
| `os/cwd` | `(os/cwd)` | 目前工作目錄 |
| `os/cd` | `(os/cd path)` | 換工作目錄 |
| `os/setlocale` | `(os/setlocale &opt locale category)` | 設 locale |

## 終端機

| 函式 | 簽名 | 說明 |
|------|------|------|
| `os/isatty` | `(os/isatty &opt file)` | ⚠ **接到人還是接到管線**——決定要不要上色／畫進度條 |

⚠ `stdout` 與 `stderr` 要**分開問**：常見情況是 stdout 被導走、stderr 還在終端機上。
終端機寬度不在 `os/`，在 `spork/rawterm`（見 [41](../docs/41-spork-終端與-shell.md)）。

## 檔案與目錄

| 函式 | 簽名 | 說明 |
|------|------|------|
| `os/stat` | `(os/stat path &opt tab\|key)` | 給 key 只取一欄；**跟隨** symlink |
| `os/lstat` | `(os/lstat path &opt tab\|key)` | 同上但**不跟隨** symlink |
| `os/dir` | `(os/dir dir &opt array)` | 只回**名字**不回路徑；目錄不存在會**報錯**不是 nil |
| `os/mkdir` | `(os/mkdir path)` | 只建一層；已存在回 `false` 不報錯 |
| `os/rmdir` | `(os/rmdir path)` | 只刪**空**目錄；非空報 `Directory not empty` |
| `os/rm` | `(os/rm path)` | 刪檔 |
| `os/rename` | `(os/rename oldname newname)` | 改名／搬移；同檔案系統內才是原子操作 |
| `os/touch` | `(os/touch path &opt actime modtime)` | 更新時間戳；⚠ **檔案不存在不會幫你建**，直接報錯 |
| `os/realpath` | `(os/realpath path)` | 解 `..` 與 symlink 給絕對路徑；⚠ 檔案**必須存在** |
| `os/readlink` | `(os/readlink path)` | 讀 symlink 指向哪（只讀一層，不解析）|
| `os/link` | `(os/link oldpath newpath &opt symlink)` | 硬連結（第三參數為真時建符號連結）|
| `os/symlink` | `(os/symlink oldpath newpath)` | 符號連結 |
| `os/open` | `(os/open path &opt flags mode)` | 低階開檔，回 file handle |
| `os/pipe` | `(os/pipe &opt flags)` | 建一對管線 |

⚠ 這一整組在 **Windows 上行為不同**（權限模型不一樣、symlink 要特權）。

## 權限

| 函式 | 簽名 | 說明 |
|------|------|------|
| `os/chmod` | `(os/chmod path mode)` | 兩種寫法都吃：`8r644` 或 `"rw-r--r--"` |
| `os/perm-string` | `(os/perm-string int)` | `8r644` → `"rw-r--r--"` |
| `os/perm-int` | `(os/perm-int bytes)` | `"rw-r--r--"` → `420`（十進位的 `8r644`）|
| `os/umask` | `(os/umask mask)` | 之後建的檔的預設權限遮罩 |

⚠ **Janet 沒有八進位字面值**：`0o644` parse 不過，`0644` 是**十進位 644**。
一律寫 `8r644`（見 [型別判斷與轉換.md](型別判斷與轉換.md) 的進位字面值）。

## 子行程

| 函式 | 簽名 | 回什麼 |
|------|------|--------|
| `os/execute` | `(os/execute args &opt flags env)` | **乾淨的 exit code**；不經 shell |
| `os/spawn` | `(os/spawn args &opt flags env)` | 一個 proc 物件（可接管線）|
| `os/shell` | `(os/shell str)` | ⚠ **exit code × 256**（C `system()` 的原始 wait status）|
| `os/proc-wait` | `(os/proc-wait proc)` | 等它結束，回 exit code |
| `os/proc-kill` | `(os/proc-kill proc &opt wait signal)` | 送信號 |
| `os/proc-close` | `(os/proc-close proc)` | 關掉它的管線 |
| `os/sigaction` | `(os/sigaction which &opt handler interrupt-interpreter)` | 掛信號處理；`nil` 表示移除 |

合法 signal keyword：`:term :int :hup :kill :usr1 :usr2 :quit`。
⚠ `:kill` **攔不到**（SIGKILL 本來就不可攔）。

> **要判斷成敗就用 `os/execute`**——`(= 1 (os/shell "exit 1"))` 永遠是 false。

## 環境變數與結束

| 函式 | 簽名 | 說明 |
|------|------|------|
| `os/getenv` | `(os/getenv variable &opt dflt)` | 沒有就回 `dflt`（省略時 `nil`）|
| `os/setenv` | `(os/setenv variable value)` | 設一個 |
| `os/environ` | `(os/environ)` | 全部，回 table |
| `os/exit` | `(os/exit &opt x force)` | ⚠ 直接砍行程；優雅收工用 `*exit*`（[40](../docs/40-內建動態變數.md)）|
| `os/sleep` | `(os/sleep n)` | ⚠ **擋住整個行程**；ev 世界要用 `ev/sleep` |
| `os/cryptorand` | `(os/cryptorand n &opt buf)` | 密碼學等級亂數（[26](../docs/26-隨機數.md)）|

## 只有 POSIX 有

`os/posix-fork` `os/posix-exec` `os/posix-chroot`
——**Windows 上根本不存在**，用之前先問 `(os/which)`。

## 時間

`os/time` `os/date` `os/mktime` `os/clock` `os/strftime` → [os-時間.md](os-時間.md)
（含 `os/date` 欄位表與 `strftime` 格式碼表；⚠ 月與日是 **0-based**）。
