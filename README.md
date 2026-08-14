# janet-lab

Janet 開發環境試驗場 —— 一個能跑的 jpm 專案 + 一整套中文教學。

Janet（1.41.2）、jpm、spork、janet-lsp 都裝在 `~/.local`（原始碼編譯、不用 sudo）。
環境細節見 [docs/00-環境與工具鏈.md](docs/00-環境與工具鏈.md)。

## 馬上試

```sh
janet bin/main.janet -n Alice -n Bob 二次元    # 打招呼（純文字）
janet bin/main.janet -n alice --upper --json   # JSON 輸出
janet bin/main.janet --help                    # argparse 自動生成的說明
jpm test                                        # 跑測試
jpm build && ./build/janet-lab --json -n world  # 編成單一執行檔再跑
```

`bin/main.janet` 一支就示範了你最常用的四樣：**CLI 參數（spork/argparse）、JSON
（spork/json）、陣列 `@[]`、雜湊表 `@{}`**。核心函式在 `janet-lab/init.janet`。

## 三個入口，看你現在要幹嘛

| 你的狀況 | 去哪 |
|----------|------|
| **想學** —— 從頭把 Janet 搞懂 | [`docs/`](docs/README.md)：00 環境 → 06 編輯器逐篇遞進，18～22 是日常會用到的，07～17 是需要時再翻的主題篇 |
| **從 C++ 過來** —— 想快速對上概念 | [`docs/01b`](docs/01b-給-C++-開發者.md)：一張概念對照表 + 五個一定會誤會的地方 |
| **想查** —— 忘了某個寫法 | [`html/index.html`](html/index.html)：分頁速查表，開瀏覽器即看 |
| **想抄** —— 現在要做某件事 | [`snippets/`](snippets/README.md)：可貼可改的片段（定時器、管線、檔案 IO、閉包、context…） |

配合教學的可跑範例在 [`examples/`](examples/README.md)。

## 結構

```
project.janet        專案宣告（依賴、要編的執行檔）
janet-lab/init.janet 核心模組（純函式）
bin/main.janet       CLI 進入點（argparse 實例）
test/basic.janet     測試
docs/                分篇教學（00～22）
html/                分頁速查表（index / data-io / peg / concurrency / ffi / env）
examples/            教學附件，配合 docs 某一篇
snippets/            做事的起點，「我要做 X，抄哪段」
modules/             能用的小模組（llm-http 打 LLM、pi-shell 包 agent CLI）
FINDINGS.md          環境與架構的實測筆記（LLM 供應商、為什麼走 litellm proxy）
FINDINGS-踩坑.md     實作時被環境／API 咬到的地方
```

## 涵蓋範圍

語言核心與資料結構、**給 C++ 開發者的概念對照**、JSON、CLI argparse、jpm 專案、
REPL 與編輯器、巨集、fiber、**PEG 解析器**、**ev channel / 真執行緒 / 內建 net**、
**C 互通（含指標與記憶體）**、子行程與信號、**env 環境表與動態變數**、
symbol↔字串、**字串與 buffer**、**檔案與檔案系統**、**錯誤處理與資源管理（defer／with）**、
**數字與位元運算**、**原型與方法（Janet 版的類別）**、**marshal 序列化與自省**。

每篇教學裡的 ⚠ 都是實際被咬過的坑，不是理論上的注意事項。
