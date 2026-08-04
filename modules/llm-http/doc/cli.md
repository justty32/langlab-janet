# CLI

[← 回 llm-http README](../README.md)


```sh
jpm build                                                   # 產出 build/llm-http

./build/llm-http --list                                     # 列出所有 endpoint（分內建／自訂）
./build/llm-http local "台灣最高的山是哪座？"                  # 基本問答
./build/llm-http -s "只回十個字內" local "1+1？"              # system 訊息
echo "把貓翻成英文" | ./build/llm-http deepseek              # 沒給 prompt 就讀 stdin
./build/llm-http --tools local "現在幾點？用工具查"           # 多輪 tool loop（內建示範工具）
./build/llm-http --image a.png local "這張圖是什麼顏色？"      # 圖像輸入，-i 可重複給多張
./build/llm-http -m qwen local "嗨"                          # 覆寫送給伺服器的 model 名
./build/llm-http --base http://127.0.0.1:4111 local "嗨"     # 換一台 proxy

# ── 自訂 endpoint 與參數 ──
./build/llm-http --endpoints ~/my-endpoints.janet qwen "嗨"   # 載入自己的設定檔
./build/llm-http --url http://127.0.0.1:1234/v1/chat/completions \
                 --model qwen3 lmstudio "嗨"                  # 直接打，不經 proxy
./build/llm-http --temperature 0 --max-tokens 64 local "嗨"   # 覆寫請求參數
./build/llm-http --param seed=7 --param stop=END local "嗨"    # 任意參數（值自動轉型）
./build/llm-http --header "x-my-tag: janet" local "嗨"        # 額外 header
./build/llm-http --api-key sk-xxx local "嗨"                  # 覆寫 Bearer token
```

| 旗標 | 短 | 做什麼 |
|------|----|--------|
| `--system` | `-s` | system 訊息 |
| `--model` | `-m` | 覆寫 model 名稱 |
| `--base` | `-b` | proxy base URL |
| `--url` | `-u` | **完整**的 chat completions 網址，給了就繞過 `--base` |
| `--api-key` | | 覆寫 `Authorization: Bearer` 的 token |
| `--header` | | 額外 header，`名字:值`，可重複 |
| `--endpoints` | | 載入 endpoint 設定檔（`.janet` 或 `.json`），可重複 |
| `--temperature` `--max-tokens` `--top-p` | | 請求參數，蓋得掉 endpoint 的 `:params` |
| `--param` | | 任意請求參數，`名字=值`（值自動轉數字／`true`／`false`／`null`），可重複 |
| `--image` | `-i` | 圖檔路徑或 http(s)/data URL，可重複 |
| `--tools` | `-t` | 啟用內建示範工具，跑多輪 tool loop |
| `--rounds` | | tool loop 最多打幾輪，預設 8 |
| `--list` | `-l` | 列出所有 endpoint 就結束 |

- **endpoint 名字不在清單裡時**，只要同時給 `--model` 與 `--url`（或 `--base`），
  CLI 會**當場組一個臨時 endpoint**；否則報「沒有這個 endpoint」並列出可用的。
- `--list` 會分開列**內建**與**自訂**，自訂的標出**是從哪個設定檔載進來的**，
  最後印 proxy base 與設定檔的探測結果。
- 預設 base 是 `http://127.0.0.1:4000`，環境變數 `LITELLM_BASE` 也可覆寫。
- **stdout 只有回答本文**（方便往下 pipe），trace／警告／錯誤一律走 stderr。
- ⚠ 沒給 prompt 又不是 tty 時會讀 stdin 讀到 EOF——沒人餵就會一直等（unix filter 的正常語意）。
  在腳本／CI 裡測請帶 `< /dev/null`。
