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
  :source ["modules/llm-http/init.janet"
           "modules/llm-http/endpoints.janet"
           "modules/llm-http/client.janet"
           "modules/llm-http/media.janet"
           "modules/llm-http/tools.janet"])

(declare-executable
  :name "llm-http"
  :entry "modules/llm-http/main.janet"
  :install false)

# pi-shell —— 把非互動 agent CLI（pi -p／claude -p）包成子行程的薄透傳殼。
(declare-source
  :prefix "pi-shell"
  :source ["modules/pi-shell/init.janet"
           "modules/pi-shell/proc.janet"])

(declare-executable
  :name "pi-shell"
  :entry "modules/pi-shell/main.janet"
  :install false)
