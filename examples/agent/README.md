# examples/agent · 兩支範例

[← examples 目錄](../README.md)｜模組本體 [`modules/agent/`](../../modules/agent/README.md)

| 檔 | 主題 | 要後端嗎 |
|----|------|----------|
| [`01-quickstart.janet`](01-quickstart.janet) | 十行組一個 agent（`default-tools` ＋ `make-agent` ＋ `run`），跟它說一句話 | 要 |
| [`02-tools-only.janet`](02-tools-only.janet) | 工具箱本身不需要模型：`sandbox`／`calc`／`list-dir`／`search-files` 直接叫 | 不用 |

## 前置條件

`01-quickstart.janet` 要一台 OpenAI 相容伺服器，見
[`examples/llm-http/README.md`](../llm-http/README.md) 怎麼把 litellm proxy 或 LM Studio 起起來。
**沒起來也不會噴 stacktrace**——印一行「連不上」加提示，然後正常結束（exit 0）。

`02-tools-only.janet` 完全離線，示範工具與 agent loop 是分開的兩件事：
loop 只是照模型的要求呼叫這些函式，函式本身不知道有沒有模型。

⚠ 這兩支**不在 `jpm test` 裡**——測試一律離線、假後端，見 `test/agent-*.janet`。
