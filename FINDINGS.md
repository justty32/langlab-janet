# 環境與架構筆記

這個 lab 在實作 LLM 相關模組時**實測**出來的耐久結論與環境雷。跟 [MISSING.md](MISSING.md)
分工：那邊記「教學缺什麼」，這邊記「環境與架構是怎樣、為什麼這樣選」。

---

## 一、LLM 供應商輪廓（決定功能優先序）

實際會用到的**就這四種**：

| 名稱 | 位置 | 憑證現況（2026-08-03） |
|------|------|------------------------|
| `local` | 本機 LM Studio `http://127.0.0.1:1234/v1` | 免認證 |
| `deepseek` | DeepSeek API | `DEEPSEEK_API_KEY` **已設**，可實測 |
| `claude` | Anthropic | `ANTHROPIC_API_KEY` **未設**；但 `claude` CLI 已認證（見第四節） |
| `openrouter` | OpenRouter | `OPENROUTER_API_KEY` **未設**；一個 endpoint 通吃含 Claude |

**使用形態**：以「純文字 ＋ tool calling（多輪 loop）」為主，**偶爾**搭配**圖像輸入**（vision）。
**不需要**音訊、圖像生成、modalities。

> 功能優先序：**tools ＞ 圖像輸入 ＞ 其他**。別為了用不到的能力增加架構複雜度或引入依賴。

## 二、定案架構：純 Janet → 本機 litellm proxy

```
純 Janet（spork/http + spork/json）
    └── http://127.0.0.1:4000        ← litellm proxy（本機、純 http）
          └── deepseek / claude / local / openrouter
```

**為什麼這樣選**：

- proxy 擋在前面 → Janet 端只需講 OpenAI 相容**一種** wire format，各家格式差異由 litellm 吸收。
- proxy 在本機是 **http 不是 https** → **spork/http 直接可打，不必為了 TLS 繞 curl**。
- **否決了 cllm 的 Janet native module**（`~/dev/lib/janet/llm.so`）：它的 `ask` 只吃單一 prompt
  字串、**沒有 `messages` 陣列**，多輪 tool loop 結構上表達不出來（其文件亦註明 tools 是單輪）。
  而它換來的 media／modalities 這邊用不到。

**已實測**：純 Janet 對這條鏈路跑完整多輪 tool loop 成功——模型要求呼叫 → 本地執行 →
以 `role:"tool"` ＋ `tool_call_id` 送回 → 模型用結果作答。

## 三、⚠ 起 litellm proxy 必須釘 fastapi 版本

新版 fastapi 移除了 `get_flat_dependant`，litellm 的 proxy 會 ImportError。**一定要釘**：

```sh
uv run --with 'litellm[proxy]' --with 'fastapi<0.119' litellm --config <yaml> --port 4000
```

會解析成 litellm 1.79.0 ＋ fastapi 0.115.14。健康檢查端點 `/health/liveliness`；
config 內用 `os.environ/<VAR>` 語法讀環境變數。

> ⚠ `litellm --version` 這條路本身有 packaging bug（`proxy_cli` 裸 import `proxy_server`），
> 別拿它判斷有沒有裝好，直接起 server 或 import `litellm.proxy.proxy_server` 比較準。

## 四、Claude 兩條路，用途不同

| 走法 | 需要 key？ | 能跑自己的 tool loop？ | 成本 |
|------|-----------|----------------------|------|
| litellm proxy → `anthropic/claude-*` | **要** `ANTHROPIC_API_KEY` | ✅ 可以（裸模型、可控 `messages`） | 一般 API 計價 |
| `claude -p`（Claude Code CLI） | **不用**（已認證） | ❌ 不行（它是 agent，自帶工具與 system prompt） | **每次呼叫都貴** |

`claude` CLI 實測：一句「只回兩個字」花 **$0.016**，因為每次都重送 Claude Code 的完整
system prompt（7,320 cache creation ＋ 11,609 cache read tokens）。當一般 chat 後端很浪費。

> **要自己的 tool loop／圖像輸入** → 走 proxy 那條。
> **要現成就能用、單次問答、不介意 agent 行為** → 走 CLI 那條。

## 五、⚠ Janet 連本機一律寫 `127.0.0.1`，不要寫 `localhost`

這台機器的 `/etc/hosts` 把 `localhost` 同時指到 `::1` 與 `127.0.0.1`，而 **Janet 的
`net/connect` 只取 getaddrinfo 的第一筆（`::1`）**，不做 happy-eyeballs。

對**只聽 IPv4** 的後端（LM Studio 就是）用 `localhost` 會直接 connection refused，
寫成 `127.0.0.1` 就通。**curl／litellm 有 happy-eyeballs 所以看不出這個差異**，
很容易誤判成「後端沒開」。

> 遇到「curl 通但 Janet 連不上」先查這一條。

## 六、OpenRouter 的兩個坑

1. **免費 slug 汰換很快**，且免費層連打幾次就撞 rate limit。用前先查
   `https://openrouter.ai/api/v1/models` 挑當下真的免費的。
2. **參數會被靜默無視**：不同模型的 `supported_parameters` 不同，送了不支援的參數
   （`response_format`／`top_p`／`seed`…）**不報錯、就是無視**——exit 0 加一份看起來像
   答案的東西。只能看回應實際符不符合預期，不能看有沒有報錯。

## 七、⚠ HTTP header 的值只能是 ASCII

`llm-http` 的 endpoint 可以帶自訂 `:headers`，但**值放中文會被伺服器擋成 400**
（實測 spork/http 的 server 就是這樣回）。HTTP header 本來就只吃 ASCII／ISO-8859-1，
要帶非 ASCII 的東西請放進 body。

症狀很不直覺：payload 一切正常、URL 也對，就是回一個沒有 body 的 `HTTP 400`。
先檢查有沒有在 header 裡塞中文。

## 八、使用者設定檔：只 parse 不 eval

兩個模組（`llm-http` 的 endpoint、`pi-shell` 的 agent）都讓使用者用一份設定檔
擴充內建清單，設計上共用同一套決定：

- **只 `parse-all` 不 `eval`**。檔案是**資料字面值**不是程式，所以裡面寫
  `(os/shell "…")` 也只是一個沒人執行的 tuple。代價是設定檔裡不能算東西
  （例如讀環境變數），所以另外開了 `:api-key-env` 這種欄位讓它宣告式地表達。
  `parse-all` 在 Janet 1.41.2 是內建的，回一個 array，多個 top-level 值會依序排好。
- **「沒有設定檔」是正常狀態**，自動探測找不到就靜靜跳過，不輸出也不報錯；
  找到了但壞掉只在 stderr 印一行中文警告然後當作沒載入——一份壞掉的設定檔
  不該讓「只想用內建那筆」的人整個跑不起來。明確呼叫 `load-endpoints!`／`load-agents!`
  時才會丟例外（那是使用者主動要求的，靜默失敗反而糟）。
- ⚠ **自動載入是 `import` 的副作用**，所以**測試一開頭要先 `reset-endpoints!`／`reset-agents!`**，
  否則開發機上有一份 `~/.config/llm-http/endpoints.janet` 就會讓測試結果跟別人不一樣。
  想要「純函式、零 IO」的那一層請直接 import `registry.janet`／`agents.janet`，
  它們不碰檔案系統。

## 九、驗證現況（2026-08-04 這次改動）

改完 registry／設定檔／參數合併之後**沒有**做真模型端到端驗證：這台機器上
**LM Studio（`127.0.0.1:1234`）與 litellm proxy（`127.0.0.1:4000`）當時都沒在跑**
（`ss -lnt` 兩個 port 都沒有 listener），而 `local` 這條線的後端就是 LM Studio，
所以就算把 proxy 起起來也打不到模型。

改用**同一個行程裡的假 OpenAI 相容後端**（spork/http 的 server）把整條路徑走完：
CLI → registry → 參數合併 → `post-chat` → HTTP → 解回應 → tool loop。
**傳輸與組裝這一段是驗過的；「真模型會不會照那些參數辦事」沒驗過。**
