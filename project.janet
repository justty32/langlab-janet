(declare-project
  :name "janet-lab"
  :description "Janet 開發環境試驗場 / dev sandbox"
  :version "0.1.0"
  # 依賴宣告在這裡；改完跑 `jpm deps` 安裝
  :dependencies ["spork"])

(declare-source
  :prefix "janet-lab"
  :source ["janet-lab/init.janet"])

# 產生一個可執行檔 build/janet-lab（jpm build）
(declare-executable
  :name "janet-lab"
  :entry "bin/main.janet"
  :install false)

# ── modules/ 底下的兩個模組 ──────────────────────────────────────────
# ⚠ declare-source 的 :source 要**逐檔列**，不要只寫目錄：jpm 是 cp -rf 過去的，
#   給目錄會變成 <modpath>/llm-http/llm-http/…（多包一層），import 路徑就跑掉了。

# llm-http —— 純 Janet 打本機 litellm proxy（OpenAI 相容），含多輪 tool loop 與圖像輸入。
(declare-source
  :prefix "llm-http"
  :source ["modules/llm-http/init.janet"        # 門面
           "modules/llm-http/endpoints.janet"   # endpoint 門面（＋觸發設定檔自動載入）
           "modules/llm-http/defaults.janet"    # 預設位址／金鑰、chat-url 怎麼組
           "modules/llm-http/builtin.janet"     # 內建四筆 endpoint 的純資料
           "modules/llm-http/spec.janet"        # 一份 endpoint 設定合不合法（純函式驗證）
           "modules/llm-http/registry.janet"    # registry：誰在表裡（define-endpoint／reset）
           "modules/llm-http/resolve.janet"     # 組成可以打的 cfg：endpoint／env-ready?
           "modules/llm-http/config.janet"      # endpoint 設定檔載入（只 parse 不 eval）
           "modules/llm-http/client.janet"      # HTTP 門面
           "modules/llm-http/transport.janet"   # HTTP／JSON 收送
           "modules/llm-http/chat.janet"        # 對話語意：chat／ask／參數合併
           "modules/llm-http/media.janet"       # 圖像輸入
           "modules/llm-http/tools.janet"       # 多輪 tool loop
           "modules/llm-http/cli.janet"         # CLI 門面＋主流程
           "modules/llm-http/cli-flags.janet"   # usage 文字與旗標定義
           "modules/llm-http/cli-args.janet"    # 命令列字串 → Janet 值
           "modules/llm-http/cli-list.janet"])  # --list 的輸出

(declare-executable
  :name "llm-http"
  :entry "modules/llm-http/main.janet"
  :install false)

# pi-shell —— 把非互動 agent CLI（pi -p／claude -p）包成子行程的薄透傳殼。
(declare-source
  :prefix "pi-shell"
  :source ["modules/pi-shell/init.janet"        # 門面
           "modules/pi-shell/proc.janet"        # 子行程管線（不認識任何 agent）
           "modules/pi-shell/spec.janet"        # 一份 agent 設定合不合法（純函式驗證）
           "modules/pi-shell/agents.janet"      # agent registry：內建資料／define-agent
           "modules/pi-shell/config.janet"      # agent 設定檔載入（只 parse 不 eval）
           "modules/pi-shell/run.janet"         # run-agent／run-pi／run-claude
           "modules/pi-shell/cli.janet"])       # CLI 的旗標消化規則

(declare-executable
  :name "pi-shell"
  :entry "modules/pi-shell/main.janet"
  :install false)
