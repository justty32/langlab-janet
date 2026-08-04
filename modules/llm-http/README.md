# llm-http

純 Janet 的 **OpenAI 相容客戶端**：對 `/v1/chat/completions` 打，支援
**多輪 tool loop**、**圖像輸入**，以及**你自己的 endpoint 與請求參數**。

```
純 Janet（spork/http + spork/json）
    ├── http://127.0.0.1:4000        ← litellm proxy（本機、純 http、不需 TLS）
    │     └── local / deepseek / claude / openrouter
    └── http://127.0.0.1:1234/…      ← 也可以直接打 LM Studio／vLLM／llama.cpp，繞過 proxy
```

走 proxy 時 Janet 這端**只講 OpenAI 相容一種格式**，四家的差異由 litellm 吸收；
不想架 proxy 時，給 endpoint 一個完整的 `:url` 就直接打任何 OpenAI 相容伺服器。
架構為什麼這樣選、環境有哪些雷 → 見 [`../../FINDINGS.md`](../../FINDINGS.md)。

**想看能跑的範例** → [`../../examples/llm-http/`](../../examples/llm-http/)（八支，中文註解，
後端沒起來時會給你看得懂的提示而不是 stacktrace）。

## 先把 litellm proxy 起來

> 只要你走的是 `:url` 直打那條路（見「自訂 endpoint」④），這一整節都可以跳過。

⚠ **`fastapi<0.119` 這個 pin 是關鍵**：新版 fastapi 移除了 `get_flat_dependant`，
litellm 的 proxy 會 ImportError。不釘就炸（背景見 FINDINGS.md 第三節）。

**設定檔已經放在 repo 裡了**（[`lite.yaml`](lite.yaml)，四個 endpoint 都配好），不用自己建：

```sh
cd <janet-lab 根目錄>
uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \
       litellm --config modules/llm-http/lite.yaml --port 4000

curl http://127.0.0.1:4000/health/liveliness      # 健康檢查，回 "I'm alive!" 就是好了
```

⚠ **`--config` 的路徑是相對「你下指令的目錄」**，不是相對那支 yaml。在別的地方跑就給絕對路徑，
否則會看到 `Exception: Config file not found: lite.yaml`。

> **缺 key 不影響啟動**：`claude`／`openrouter` 那兩筆即使環境變數沒設，proxy 照樣起得來，
> 只有真的呼叫到那個 model 時才會報錯。所以不必為了試 `local` 先去湊齊四把金鑰。

`lite.yaml` 的內容（`os.environ/<VAR>` 是 litellm 讀環境變數的語法，金鑰不落版控）：

```yaml
model_list:
  - model_name: local
    litellm_params:
      model: openai/google/gemma-4-e4b
      api_base: http://127.0.0.1:1234/v1     # LM Studio。⚠ 寫 127.0.0.1 不要寫 localhost
      api_key: dummy
  - model_name: deepseek
    litellm_params:
      model: deepseek/deepseek-v4-flash      # ⚠ 現行 id 是 v4-flash／v4-pro，不是 deepseek-chat
      api_key: os.environ/DEEPSEEK_API_KEY
  - model_name: claude
    litellm_params:
      model: anthropic/claude-sonnet-5
      api_key: os.environ/ANTHROPIC_API_KEY
  - model_name: openrouter
    litellm_params:
      model: openrouter/google/gemma-4-31b-it:free
      api_key: os.environ/OPENROUTER_API_KEY
```

`lite.yaml` 裡的 `model_name` 就是本模組內建 endpoint 的 `:model`——**兩邊要對得起來**。
要換 provider 就改 yaml，Janet 這邊一行都不用動。

## 四個內建 endpoint 的現況

| 名字 | 後端 | 憑證 | 吃圖 | 驗證狀態 |
|------|------|------|------|----------|
| `local` | 本機 LM Studio | 免 | ✅ gemma-4 系列 | **已實測**（問答／tool loop／圖像） |
| `deepseek` | DeepSeek API | `DEEPSEEK_API_KEY` | ❌ 純文字 | **已實測**（問答） |
| `claude` | Anthropic | `ANTHROPIC_API_KEY` | ✅ | ⚠ **未實測**（本機沒設 key） |
| `openrouter` | OpenRouter | `OPENROUTER_API_KEY` | 看你選的 slug | ⚠ **未實測**（本機沒設 key） |

⚠ **圖像要挑支援的模型**：送圖給純文字模型（例如 DeepSeek），行為從報錯到**靜默無視**都有可能。
`--image` 搭配標記為 `:vision? false` 的 endpoint 時 CLI 會先在 stderr 警告。

⚠ **OpenRouter 兩個坑**（細節見 FINDINGS.md 第六節）：免費 slug 汰換很快、免費層很快撞 rate limit；
而且**送了模型不支援的參數不會報錯、就是被無視**，只能看回應內容判斷。
實務上它的好處是**一個端點通吃多家（含 Claude）**，所以在沒有 `ANTHROPIC_API_KEY` 的情況下，
走 OpenRouter 也是碰 Claude 的一條路。

## Claude 有兩條路，用途不同

| 想做的事 | 走哪 |
|----------|------|
| 自己的**多輪 tool loop**、**圖像輸入**、可控的 `messages[]` | **本模組**的 `claude` endpoint（需要 `ANTHROPIC_API_KEY`） |
| 現成就能用、單次問答、不介意它自帶工具與 agent 行為 | [`../pi-shell/`](../pi-shell/README.md) 的 `run-claude`（免 key，但每次呼叫都貴） |

`claude -p` 是 **agent 不是 chat completion 端點**——沒有 `messages[]` 可控、自帶 bash/edit/write
與自己的 system prompt，跑不了呼叫端自己的 tool loop，所以刻意**不**放進本模組。

## 這份說明拆成幾支

README 只放「怎麼跑起來」；細節按主題分在 [`doc/`](doc/)：

| 檔 | 內容 |
|----|------|
| [自訂 endpoint](doc/自訂-endpoint.md) | 設定認得的欄位、inline table／`define-endpoint`／設定檔三種寫法 |
| [直接指定 `:url` 與請求參數](doc/參數與繞過-proxy.md) | 繞過 proxy 直接打任何 OpenAI 相容伺服器、參數合併優先序 |
| [CLI](doc/cli.md) | 所有旗標與實例 |
| [當函式庫用](doc/當函式庫用.md) | `ask`／`chat`／tool loop／system 訊息／公開 API 一覽 |
| [拆檔與限制](doc/拆檔與限制.md) | 哪個檔管什麼、沒做的事、實測踩過的點 |

**怎麼 import（路徑規則、`:as`、裝起來用裸名字）→ 見 [`../README.md`](../README.md#怎麼-import-這些模組)。**
