#!/usr/bin/env janet
# CLI 進入點 —— 只有一句：把命令列交給 cli.janet。
#
# 真正的參數解析、輸出格式、endpoint 解析在 ./cli.janet（拆出去是為了能離線測），
# 核心邏輯在 endpoints／client／media／tools 那幾支。
#
# 跑法：
#   janet modules/llm-http/main.janet local 你好                     # 直接跑
#   jpm build && ./build/llm-http local 你好                          # 編成單一執行檔
#   echo "翻成英文：貓" | ./build/llm-http deepseek                   # 沒給 prompt 就讀 stdin
#   ./build/llm-http --list                                           # 列出所有 endpoint
#   ./build/llm-http --tools local "現在幾點？用工具查"                # 跑多輪 tool loop
#   ./build/llm-http --image /tmp/a.png local "這是什麼？"             # 丟圖進去（可重複給）
#   ./build/llm-http --base http://127.0.0.1:4111 local 嗨            # 換一台 proxy
#   ./build/llm-http --endpoints ~/my-endpoints.janet qwen 嗨          # 載入自己的 endpoint
#   ./build/llm-http --url http://127.0.0.1:1234/v1/chat/completions \
#                    --model qwen3 lmstudio 嗨                        # 直接打，不經 proxy
#   ./build/llm-http --temperature 0 --max-tokens 64 local 嗨         # 覆寫請求參數

(import ./cli)

(defn main
  [& args]
  (cli/run args))
