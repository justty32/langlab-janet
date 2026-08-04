# 自訂 endpoint

[← 回 llm-http README](../README.md)


內建只有四筆，但**你不需要改 repo 原始碼**就能加自己的。四條路，由輕到重：

| 想做的事 | 走哪 |
|----------|------|
| 臨時用一次，不想留下痕跡 | ① **inline table** |
| 程式裡註冊一個名字，之後照舊用名字取 | ② `define-endpoint` |
| 一次設定、每次都在，而且不進版控 | ③ **設定檔** |
| **繞過 litellm proxy**，直接打 LM Studio／vLLM／llama.cpp | ④ 給完整的 `:url`（跟 ①②③ 任一搭配） |

能跑的完整示範 → [`../../examples/llm-http/06-custom-endpoint.janet`](../../../examples/llm-http/06-custom-endpoint.janet)。

## 一份 endpoint 設定認得的欄位

只有 `:model` 必填，其餘都可省略。**欄位名打錯會在當下被擋下來並列出可用欄位**，
不會靜靜被忽略（`:vision?` 打成 `:vision` 這種最容易出事）。

| 欄位 | 意思 |
|------|------|
| `:model` | **必填**。送給 proxy／伺服器的 model 名稱 |
| `:base` | proxy base URL；沒給就用 `http://127.0.0.1:4000`（`LITELLM_BASE` 可覆寫） |
| `:url` | **完整**的 chat completions 網址；給了就完全不看 `:base` |
| `:api-key` | Bearer token；沒給就用 `proxy-key`（`LITELLM_API_KEY` 可覆寫，預設 `"dummy"`） |
| `:api-key-env` | 從這個環境變數讀 token（設定檔裡不落金鑰時用） |
| `:headers` | 額外的 request header，`{"名字" "值"}`，**同名蓋掉預設的**（含 `Authorization`） |
| `:params` | 這條線的**預設請求參數**，`{:temperature 0.2 :max_tokens 512 :top_p 0.9}` |
| `:env` | 這條線在 **proxy 那端**需要的環境變數（只影響 `--list` 的提示） |
| `:vision?` | 這條線指到的模型吃不吃圖；**不確定就別給**（`nil` ＝ 不表態，CLI 不會警告） |
| `:note` | 一句話說明，會出現在 `--list` |

⚠ `:params` 的 key 用 **payload 的原名（snake_case）**：`:max_tokens` 不是 `:max-tokens`。
⚠ `:headers` 的值請用 **ASCII**——HTTP header 本來就只吃 ASCII／ISO-8859-1，
放中文會被伺服器擋成 400。要帶中文請放進 body。
⚠ `:url` 只能是 `http://`。spork/http **沒有 TLS**，`https://` 一定打不通（不是設定寫錯）。

## ① inline table：完全不註冊

`endpoint` 的第一個參數除了名字字串，也吃 table／struct：

```janet
(def cfg (llm/endpoint {:model "qwen3" :base "http://127.0.0.1:4000" :vision? true}))
(llm/ask cfg "嗨")
```

⚠ 這條會**驗證**設定：缺 `:model` 之類的問題會**當場丟中文錯誤**（不是回 `nil`，
也不是等到打 HTTP 才炸）。

## ② `define-endpoint`：註冊成有名字的

```janet
(llm/define-endpoint "qwen" {:model "qwen3" :params {:temperature 0.2}})
(llm/endpoint "qwen")                       # 之後照舊用名字取
(llm/endpoint-source "qwen")                # → :runtime（--list 會拿它分內建／自訂）
(llm/undefine-endpoint! "qwen")             # 拿掉
(llm/reset-endpoints!)                      # 打回「只剩內建四筆」
```

## ③ 設定檔：不必改 repo、也不必 commit 自己的設定

**範本（含中文註解）：[`endpoints.example.janet`](../endpoints.example.janet)** —— 複製一份去改。

放到下列任一位置，`import` 這個模組時就會**自動載入**（依序找，第一個找到的贏）：

1. 環境變數 `LLM_HTTP_ENDPOINTS` 指的檔案
2. `$XDG_CONFIG_HOME/llm-http/endpoints.janet`
3. `~/.config/llm-http/endpoints.janet`

也可以不靠自動探測、明確指定：

```janet
(llm/load-endpoints! "/路徑/endpoints.janet")     # 明確載入，出問題會丟中文錯誤
(llm/autoload-endpoints!)                          # 自動探測一次，回載到的路徑或 nil
(llm/config-candidates)                            # 會依序看哪些位置
llm/loaded-files                                   # 這個行程載過哪些檔
```

```sh
./build/llm-http --endpoints /路徑/endpoints.janet qwen "嗨"
```

檔案長這樣（最外層一張表：名字 → 設定；可以有多張，依序疊加）：

```janet
{"qwen"     {:model "qwen3" :params {:temperature 0.2}}
 "lmstudio" {:model "google/gemma-4-e4b"
             :url   "http://127.0.0.1:1234/v1/chat/completions"}}
```

- **只 parse 不 eval**：內容是一份 Janet **資料字面值**（走 `parse-all`），
  裡面寫 `(os/shell "…")` 也只是一個沒人執行的 tuple。所以不要在裡面寫 `(def …)`／`(import …)`。
- 副檔名是 `.json` 就改走 spork/json，欄位名一樣。
- **沒有設定檔是正常狀態**：自動探測找不到就靜靜跳過，不會有任何輸出、也不會報錯。
  找到了但格式壞掉，會在 stderr 印一行中文警告然後當作沒載入——一份壞掉的設定檔
  不該讓「只想打內建 `local`」的人整個跑不起來。
- 明確呼叫的 `load-endpoints!` 則相反：檔案不存在／括號少收／某一筆缺 `:model`，
  一律丟**看得懂的中文錯誤**（會告訴你是哪個檔的哪一筆）。
