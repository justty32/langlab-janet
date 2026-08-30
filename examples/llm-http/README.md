# examples/llm-http · 打 LLM 的八支範例

[← examples 目錄](../README.md)｜模組本體 [`modules/llm-http/`](../../modules/llm-http/README.md)

**跑起來就是一份教材**——從兩行問答一路到多輪 tool loop 與圖像輸入。
建議照編號順序看，每支只多教一件事。


| 檔 | 主題 | 要後端嗎 |
|----|------|----------|
| `01-minimal.janet` | 最小問答：`endpoint` ＋ `ask` 兩行 | 要 |
| `02-system-prompt.janet` | system prompt 的三種給法（`ask` 第二參數／`with-tools` 的 `:system`／自組 messages） | 要 |
| `03-multi-turn.janet` | 多輪對話：自己維護 `messages` 陣列、歷史怎麼截斷 | 要 |
| `04-tools.janet` | tool loop：自訂工具、多個工具、handler 丟例外時的行為 | 要（且模型要支援 tool calling） |
| `05-vision.janet` | 圖像輸入：content parts 長怎樣、data URI、多張圖 | 要（且模型要吃圖） |
| `06-custom-endpoint.janet` | **自訂 endpoint 的四種寫法**：inline／`define-endpoint`／設定檔／直接指定 `:url` 繞過 proxy | 前半段不用 |
| `07-params.janet` | 請求參數的覆寫與**合併優先序**（`build-payload` 是純函式，印得出最終 payload） | 前半段不用 |
| `08-errors.janet` | 錯誤處理：連不上／名字打錯／設定檔壞掉／模型不吃圖…每種長什麼樣 | **完全不用** |

## 前置條件

`01`–`05` 與 `06`／`07` 的最後一段需要一台 **OpenAI 相容伺服器**，二選一：

```sh
# (a) litellm proxy（四個 endpoint 都配好了；⚠ fastapi<0.119 這個 pin 不能省）
cd <janet-lab 根目錄>
uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \
       litellm --config modules/llm-http/lite.yaml --port 4000

# (b) 只開 LM Studio，走 06 的 ④「直接指定 :url」那條，連 proxy 都不用架
```

- **沒起來也不會噴 stacktrace**：每支都用 `protect` 把例外接下來，
  印一行「連不上 …」加上怎麼把後端起起來的提示。
- ⚠ 位址一律寫 `127.0.0.1` 不要寫 `localhost`（`::1` 陷阱，見 [FINDINGS.md](../../FINDINGS.md) 第五節）。
- ⚠ 這些 example **不在 `jpm test` 裡**——測試一律離線，不打網路、不呼叫真模型。

