# CLI 的旗標定義與 usage 文字 —— 只有資料跟一個 parse-args，沒有流程。

(import spork/argparse :as ap)

(def usage
  (string "agent —— 用內建工具跑一個能讀檔、算數、抓網頁的 agent（站在 llm-http 上面）\n"
          "  用法：agent [旗標] [問題...]\n"
          "  沒給問題、或給了 -i，就進互動模式：一行一問，/quit 離開。\n"
          "  預設只讀不寫、不跑指令；--allow-write／--allow-shell 才會開。\n"
          "  stdout 只有答案本文，trace 與錯誤都走 stderr。"))

(def flags
  "argparse 的旗標定義（攤平成 key/opts 序列，直接 ;flags splice 進 ap/argparse）。"
  ["endpoint"    {:kind :option :short "e" :default "local"
                  :help "endpoint 名字（內建 local/deepseek/claude/openrouter 或自訂），預設 local。"}
   "root"        {:kind :option :short "r" :default "."
                  :help "檔案工具的根目錄（sandbox），預設目前目錄；跳出去的路徑會被拒絕。"}
   "system"      {:kind :option :short "s" :help "system 訊息。"}
   "allow-write" {:kind :flag :help "開放 write-file（寫 root 底下的檔）。"}
   "allow-shell" {:kind :flag :help "開放 run-command（跑指令）。搭配 --shell-allow 給白名單。"}
   "shell-allow" {:kind :accumulate
                  :help "run-command 允許的指令前綴，可重複給（例如 --shell-allow ls --shell-allow 'git status'）。"}
   "no-http"     {:kind :flag :help "拿掉 http-get 工具。"}
   "max-steps"   {:kind :option :help "一次提問最多打幾次模型，預設 10。"}
   "verbose"     {:kind :flag :short "v" :help "把每一步（模型／工具／耗時／tokens）印到 stderr。"}
   "trace-file"  {:kind :option :help "把每一步追加寫進這個檔（跟 -v 可以同時用）。"}
   "save"        {:kind :option :help "每答完一題就把對話存成這個 JSON 檔。"}
   "resume"      {:kind :option :help "從這個 JSON 檔讀回對話再繼續。"}
   "interactive" {:kind :flag :short "i" :help "互動模式：從 stdin 一行一問。"}
   "model"       {:kind :option :short "m" :help "覆寫送給伺服器的 model 名稱。"}
   "base"        {:kind :option :short "b" :help "proxy base URL。"}
   "url"         {:kind :option :short "u" :help "完整的 chat completions 網址，給了就繞過 --base。"}
   "temperature" {:kind :option :help "取樣溫度。"}
   "max-tokens"  {:kind :option :help "回應長度上限。"}
   "image"       {:kind :accumulate
                  :help "圖檔路徑或 URL，可重複給（只跟第一個問題一起送）。"}
   :default      {:kind :accumulate :help "問題本文（多個字會用空白接起來）。"}])

(defn parse-args
  "解析命令列（argv 第 0 個是執行檔自己）。失敗或 --help 時回 nil，usage 已由 argparse 印出。"
  [argv]
  (with-dyns [:args argv]
    (ap/argparse usage ;flags)))
