# examples/agent-tutorial · 從零寫一個 AI agent（可跑範例）

[← examples 目錄](../README.md)｜教學正文 [`docs/47`](../../docs/47-llm-api-是什麼.md)

**七支範例，全部離線跑得完**——不需要金鑰、不需要網路、不需要先架後端。
每支都在同一個行程裡起一台假的 OpenAI 相容伺服器（[`fake-server.janet`](fake-server.janet)），
所以第一次接觸 LLM API 的人可以先把整條流程看完，再去接真模型。

```sh
janet examples/agent-tutorial/47-api.janet
```

| 檔 | 配哪篇 | 學到什麼 |
|----|--------|----------|
| [`47-api.janet`](47-api.janet) | [47](../../docs/47-llm-api-是什麼.md) | payload 長什麼樣、POST 出去、從回應挖 content／finish_reason／usage |
| [`47b-multi-turn.janet`](47b-multi-turn.janet) | [47b](../../docs/47b-多輪對話.md) | 歷史要自己維護、system prompt、截斷策略 |
| [`47c-tools.janet`](47c-tools.janet) | [47c](../../docs/47c-tool-calling.md) | tool calling 四步逐步印出來、JSON schema、handler 丟例外 |
| [`47d-agent-loop.janet`](47d-agent-loop.janet) | [47d](../../docs/47d-自己寫-agent-loop.md) | 十七行手寫 agent loop，再對照 `with-tools` |
| [`47e-vision.janet`](47e-vision.janet) | [47e](../../docs/47e-圖像輸入.md) | content parts、data URI、哪些模型吃圖 |
| [`47f-errors.janet`](47f-errors.janet) | [47f](../../docs/47f-錯誤與成本.md) | 連不上／401／429／截斷／重試／估成本 |
| [`47g-real-backend.janet`](47g-real-backend.janet) | [47g](../../docs/47g-接真後端.md) | 換成真後端、金鑰放哪、開工前的檢查清單 |

## 假後端怎麼換成真的

每支範例裡都有這一行：

```janet
(def cfg (llm/endpoint {:model "fake-model" :url (假 :url) :api-key "sk-fake"}))
```

把它換成真的位址與金鑰就是在打真模型，其餘一行都不用改：

```janet
(def cfg (llm/endpoint "local"))                                   # 走 litellm proxy
(def cfg (llm/endpoint {:model "google/gemma-4-e4b"
                        :url "http://127.0.0.1:1234/v1/chat/completions"}))   # 直打 LM Studio
```

怎麼把後端起起來 → [`modules/llm-http/README.md`](../../modules/llm-http/README.md)。
需要後端才能跑、但會打到真模型的範例在 [`examples/llm-http/`](../llm-http/README.md)。

## `fake-server.janet` 怎麼用

- **沒有頂層副作用**：import 它不會開 port，要自己 `(fs/start :port …)`，用完 `(fs/stop …)`。
  ⚠ 忘了關的話行程結束不了（ev loop 還在等那個 server）。
- `:reply` 收一個 `(fn [payload 第幾次] -> [HTTP狀態碼 回應表])`，
  所以要模擬 401／429／截斷都只是回不同的東西。
- `(假 :log)` 是每次收到的 payload，拿來證明「我到底送了什麼上去」。
- 各範例用不同的 port（45821–45828），同時跑也不會撞。

⚠ 這些範例**不在 `jpm test` 裡**（測試一律離線且不起 server）；驗證方式是直接跑，每支 exit 0。
