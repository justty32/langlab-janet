#!/usr/bin/env janet
# CLI 進入點 —— 只有一句：把命令列交給 cli.janet。
#
# 跑法：
#   janet modules/agent/main.janet "這個資料夾有什麼？"                # 直接跑（預設 endpoint local）
#   jpm build && ./build/agent -e local -r . "幫我看看這個資料夾有什麼"   # 編成執行檔
#   ./build/agent -v "1234 乘 5678 是多少？用工具算"                    # -v 看每一步
#   ./build/agent --allow-write -r /tmp/work "把結果寫進 out.txt"        # 開放寫檔
#   ./build/agent --allow-shell --shell-allow ls --shell-allow "git status" "看一下 git 狀態"
#   ./build/agent --save 對話.json "記住我叫小明"                       # 存對話
#   ./build/agent --resume 對話.json "我叫什麼？"                       # 讀回再問
#   ./build/agent -i                                                    # 互動模式，/quit 離開

(import ./cli)

(defn main
  [& args]
  (cli/run args))
