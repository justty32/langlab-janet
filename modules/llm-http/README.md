# llm-http

純 Janet 的 **litellm proxy 客戶端**：對本機 proxy 打 OpenAI 相容的
`/v1/chat/completions`，支援 **多輪 tool loop** 與 **圖像輸入**。

```
純 Janet（spork/http + spork/json）
    └── http://127.0.0.1:4000        ← litellm proxy（本機、純 http、不需 TLS）
          └── local / deepseek / claude / openrouter
```

proxy 擋在前面，所以 Janet 這端**只講 OpenAI 相容一種格式**，四家的差異由 litellm 吸收。
架構為什麼這樣選、環境有哪些雷 → 見 [`../../FINDINGS.md`](../../FINDINGS.md)。

## 先把 litellm proxy 起來

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

`lite.yaml` 裡的 `model_name` 就是本模組 `endpoints.janet` 的 `:model`——**兩邊要對得起來**。
要換 provider 就改 yaml，Janet 這邊一行都不用動。

## 四個 endpoint 的現況

| 名字 | 後端 | 憑證 | 吃圖 | 驗證狀態 |
|------|------|------|------|----------|
| `local` | 本機 LM Studio | 免 | ✅ gemma-4 系列 | **已實測**（問答／tool loop／圖像） |
| `deepseek` | DeepSeek API | `DEEPSEEK_API_KEY` | ❌ 純文字 | **已實測**（問答） |
| `claude` | Anthropic | `ANTHROPIC_API_KEY` | ✅ | ⚠ **未實測**（本機沒設 key） |
| `openrouter` | OpenRouter | `OPENROUTER_API_KEY` | 看你選的 slug | ⚠ **未實測**（本機沒設 key） |

⚠ **圖像要挑支援的模型**：送圖給純文字模型（例如 DeepSeek），行為從報錯到**靜默無視**都有可能。
`--image` 搭配標記為不吃圖的 endpoint 時 CLI 會先在 stderr 警告。

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

## CLI

```sh
jpm build                                                   # 產出 build/llm-http

./build/llm-http --list                                     # 列出四個 endpoint 與憑證現況
./build/llm-http local "台灣最高的山是哪座？"                  # 基本問答
./build/llm-http -s "只回十個字內" local "1+1？"              # system 訊息
echo "把貓翻成英文" | ./build/llm-http deepseek              # 沒給 prompt 就讀 stdin
./build/llm-http --tools local "現在幾點？用工具查"           # 多輪 tool loop（內建示範工具）
./build/llm-http --image a.png local "這張圖是什麼顏色？"      # 圖像輸入，-i 可重複給多張
./build/llm-http -m qwen local "嗨"                          # 覆寫送給 proxy 的 model 名
./build/llm-http --base http://127.0.0.1:4111 local "嗨"     # 換一台 proxy
```

- 預設 base 是 `http://127.0.0.1:4000`，環境變數 `LITELLM_BASE` 也可覆寫。
- **stdout 只有回答本文**（方便往下 pipe），trace／警告／錯誤一律走 stderr。
- ⚠ 沒給 prompt 又不是 tty 時會讀 stdin 讀到 EOF——沒人餵就會一直等（unix filter 的正常語意）。
  在腳本／CI 裡測請帶 `< /dev/null`。

## 當函式庫用

**怎麼 import（路徑規則、`:as`、裝起來用裸名字）→ 見 [`../README.md`](../README.md#怎麼-import-這些模組)。**
下面假設你的檔案在根目錄下一層（`test/`、`bin/` 那種）：

```janet
(import ../modules/llm-http/init :as llm)

(def cfg (llm/endpoint "local"))                    # 或 "deepseek"／"claude"／"openrouter"
(print (llm/ask cfg "台灣最高的山是哪座？"))          # 一行式問答
(print (llm/ask cfg "1+1？" "只回數字，不要解釋"))    # 第二個參數是 system 訊息
(print (llm/ask cfg "這是什麼？" nil ["a.png"]))     # 第三個參數是圖檔陣列
```

`ask` 的簽名是 `(ask cfg prompt &opt system images)`——system 跟 images 都可省略，
只要 images 不要 system 時中間給 `nil`。

### tool loop

`with-tools` 把「模型要工具 → 本地執行 → 結果送回 → 模型作答」這個循環包起來，
自己轉圈直到模型不再要求工具，並有 `:max-rounds` 上限防無限迴圈。

```janet
(def tools
  [(llm/tool-spec "get_weather" "查詢城市目前天氣"
                  {:type "object"
                   :properties {:city {:type "string"}}
                   :required ["city"]})])

# handlers 是「工具名 → Janet 函式」；函式收一張解好的參數 table，
# 回字串（或任何東西，非字串會被 encode 成 JSON）
(def handlers
  {"get_weather" (fn [args] {:city (args :city) :temp_c 31 :cond "晴"})})

(def out (llm/with-tools cfg
                         @[@{:role "user" :content "台北天氣？用工具查"}]
                         tools handlers
                         :system "你只能用繁體中文回答"   # 可省略，見下
                         :max-rounds 8
                         :trace (fn [name args result] (eprintf "→ %s" name))))
(print (out :text))        # 最終答案；撞到上限時是 nil，(out :exhausted) 為 true
(out :messages)            # 完整歷史，含 assistant 的 tool_calls 與 role:"tool" 的結果
```

handler 自己丟例外不會炸掉整條 loop——錯誤會被**當成工具結果送回模型**，讓它有機會改參數重試。

#### tool loop 的 system 訊息

`with-tools` 吃的是**完整的 `messages` 陣列**（tool loop 本來就要你掌控整段歷史），
所以 system 有兩種給法，擇一即可：

```janet
# ① 用 :system 具名參數 —— 跟 ask 對齊，省得自己組 role/content
(llm/with-tools cfg @[@{:role "user" :content "…"}] tools handlers
                :system "你只能用繁體中文回答")

# ② 自己放進 messages 第一則 —— 想更精細控制歷史時用這個
(llm/with-tools cfg @[@{:role "system" :content "你只能用繁體中文回答"}
                      @{:role "user"   :content "…"}]
                tools handlers)
```

⚠ **`:system` 只在 `messages` 第一則還不是 system 時才會插入**——已經自己放了就會被忽略，
避免一次送兩則 system 讓模型無所適從。要換掉原本那則就直接改 `messages`，別靠 `:system` 覆蓋。

CLI 的 `-s` 走的是 ②（先組進 `messages` 再交給 loop），所以 `-s` 跟 `--tools` 可以一起用：

```sh
./build/llm-http --tools -s "你只能用日文回答，一句話。" local "現在幾點？用工具查。"
# → 工具 now()
# ← 2026-08-03T22:00:13Z
# 現在時刻は協定世界時で2026年8月3日 22時0分13秒です。
```

## 拆檔

| 檔案 | 管什麼 |
|------|--------|
| `init.janet` | 門面，把下面四個檔的公開函式 re-export 出來 |
| `endpoints.janet` | endpoint／model 設定表、proxy base URL |
| `client.janet` | HTTP／JSON 收送、取答案（`post-chat`／`chat`／`ask`） |
| `media.janet` | 圖像輸入：圖檔 → base64 data URI → content parts |
| `tools.janet` | 多輪 tool loop（`tool-spec`／`with-tools`／內建示範工具） |
| `main.janet` | CLI 進入點 |

只想要某一層也可以直接 import 個別檔案，例如 `(import ../modules/llm-http/tools)`。

## 沒做的事

- **串流（`stream: true`）不支援**。SSE 要逐行解析 `data: {...}`，spork/http 的 client 是
  「讀完整份 response 再回」的形狀，對 SSE 支援有限。需要串流請另外想辦法。
- **音訊、圖像生成、modalities 不做**（用不到，見 FINDINGS.md 第一節）。

## 幾個實測踩過的點

- `(res :body)` 是 **buffer**，丟給 `json/decode` 前要先 `(string …)` 包一層。
- `json/decode` 第二個參數給 `true`，key 才會變 keyword（否則 `get-in` 全部落空）。
- `:function :arguments` 是一段 **JSON 字串**，要再 `json/decode` 一次才是參數 table。
- 有 `tool_calls` 時要把**整則 assistant message 原樣接回 messages**，只留 content 會讓後面的
  `role:"tool"` 找不到錨點。
- `spork/json` 會把非 ASCII **逃逸成 `\uXXXX`**（合法 JSON，對端解得開，但自己 debug 時別嚇到）。
- ⚠ 連本機**一律寫 `127.0.0.1`**，不要寫 `localhost`（`::1` 陷阱，見 FINDINGS.md 第五節）。
