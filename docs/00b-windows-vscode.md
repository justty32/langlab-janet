# 00b · 在 Windows + VS Code 玩 Janet

00 篇是 Manjaro（原始碼編譯）。這篇是同一套 repo 搬到 **Windows 11 + VS Code** 實測跑通的完整過程與坑。

## 前提（本機已有）

| 東西 | 位置 |
|------|------|
| `janet` 1.41.2、`jpm` | `%LOCALAPPDATA%\Apps\Janet\bin`（已在 PATH） |
| mingw-w64 gcc（含 `ar`／`dlltool`／`gendef`） | `C:\dev\mingw64\bin`（已在 PATH） |
| VS Code | 已裝，`code` CLI 可用 |

沒裝 Visual Studio，所以**不走 MSVC**，native 全用 mingw gcc。

## 坑 1：jpm 預設是 MSVC，要改成 mingw

Windows 版 janet 附的 `jpm` 預設 `cc = cl.exe`（`is-msvc true`）。沒 VS 就編不了 native（spork/json）。
改法：把 `<Janet>\Library\jpm\default-config.janet` 換成 mingw 值（官方 make-config 的 `:mingw` profile）：

```
:cc "cc"  :cc-link "cc"  :ar "ar"  :is-msvc false
:cflags @["-std=c99"]  :dynamic-cflags @["-fPIC"]  :dynamic-lflags @["-shared"]
:janet-lflags @["-lws2_32" "-lwsock32" "-lpsapi"]   # Windows socket libs
:statext ".a"  :importlibext ".dll.a"  :modext ".dll"
# :janet-importlib 照舊指向 <Janet>\C\janet.lib —— 這份 MSVC import lib 連 mingw 也吃得動
```
原檔已備份成 `default-config.janet.msvc-backup`。

還改了 jpm 一個 bug：`Library\jpm\cc.janet` 的 `link-c`，mingw 下加 `-Wl,--out-implib,<name>.dll.a`，
否則 gcc 不產模組 import lib、但 jpm 安裝步驟又要複製它 → `File not found - json.dll.a`。

## 坑 2：`jpm deps` 一定要在 PowerShell 跑，別在 git-bash

在 git-bash 下 jpm 呼叫 `git submodule` 會炸（`git-sh-setup: file not found`，是 jpm `patch-env`
重建 PATH 造成）。**在 PowerShell（VS Code 內建終端）跑就沒事**：

```powershell
jpm deps        # 下載並用 gcc 編 spork，json.dll 進 <Janet>\Library\spork\
janet test\basic.janet   # 所有測試通過 ✓
```

## 坑 3：要 `jpm build` 出獨立執行檔，得自備兩個 mingw 靜態庫

Windows dist 只附 MSVC 的 `libjanet.lib`，mingw 連 exe 需要 `libjanet.a`；spork 的靜態模組同理。
用附的 `janet.c` 原始碼自己編（一次就好，放進對應目錄）：

```powershell
cd $env:LOCALAPPDATA\Apps\Janet\C
cc -std=c99 -O2 -c janet.c -o janet.o; ar rcs libjanet.a janet.o
# spork/json 靜態庫（entry 名固定，見 json.meta.janet）
cc -std=c99 -O2 -c <spork-cache>\src\json.c -DJANET_ENTRY_NAME=janet_module_entry_spork_47_json -I. -o j.o
ar rcs ..\Library\spork\json.a j.o
```
之後 `jpm build` → `build\janet-lab.exe --json -n world` 可跑。
⚠ `pi-shell` / `llm-http` 兩個模組的獨立 exe 還會缺別的 spork 靜態庫（base64…），
動態載入（直接 `janet` 跑）不受影響；要它們的 exe 再照上式補對應 `.a`。

## 坑 4：中文只有「當命令列參數」會亂碼

- 原始碼／檔案裡的中文：**正常**（janet 讀 bytes、檔案是 UTF-8）。
- 中文當 argv（`janet f.janet 二次元`、`janet -e '(print "你好")'`）：**會壞**。
  這是 Windows argv 走系統 ANSI codepage、`chcp 65001` 救不了的老問題；根治要開
  OS「Beta: 使用 UTF-8 提供全球語言支援」（全系統、要重開機）。平常別把中文當參數傳即可。

## VS Code

- 擴充：**Janet++**（`CalebFiggers.vscode-janet-plus-plus`，已裝）。求值 `Alt+E`（游標處 form）、
  `Alt+L`（載入整檔進 REPL）、存檔自動排版、ParEdit 結構編輯 —— 等同 nvim 的 Conjure。
  官方 `janet-lang.vscode-janet` 只有高亮，Janet++ 是其超集，二選一即可。
- repo 內 `.vscode/`：`settings.json`（UTF-8、預設 PowerShell）、`tasks.json`（跑檔／測試／build，
  跨平台）、`extensions.json`（推薦 Janet++）。`Ctrl+Shift+B` 跑目前檔案。

## 之後在 Manjaro 用 VS Code

Linux 乾淨很多：gcc 原生、無 MSVC 問題、無 argv 亂碼、`jpm deps/build` 直接動。
只要 `code --install-extension CalebFiggers.vscode-janet-plus-plus`，同一份 `.vscode/` 直接共用
（tasks 已對 Windows/Linux 分別設定）。nvim 那套（Conjure）見 [06](06-編輯器與-REPL.md)。
