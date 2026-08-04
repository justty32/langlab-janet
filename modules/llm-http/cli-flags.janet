# CLI 的**旗標定義**與 usage 文字 —— 只有資料跟一個 parse-args，沒有任何流程。
#
# 抽成獨立一支的理由：旗標清單是最常被翻、也最常被改的東西，跟主流程混在一起
# 每次要找都得捲很久；而且測試想拿到同一份定義時，import 這支就好。

(import spork/argparse :as ap)

(def usage
  (string "llm-http —— 純 Janet 打 OpenAI 相容端點（litellm proxy／LM Studio／…）\n"
          "  用法：llm-http [旗標] <endpoint 名字> [prompt 文字...]\n"
          "  endpoint 名字可以是內建的 local/deepseek/claude/openrouter，也可以是你自己\n"
          "  用 --endpoints 設定檔註冊的；名字不在清單裡時，只要同時給 --url（或 --base）\n"
          "  ＋ --model，就會當場組一個臨時 endpoint。\n"
          "  沒給 prompt 文字就讀 stdin 到 EOF 當 prompt；\n"
          "  ⚠ stdin 非 tty 又沒人餵會一直卡著等（unix filter 正常語意），測試請加 < /dev/null。\n"
          "  stdout 只有回答本文，診斷與錯誤都走 stderr。"))

(def flags
  ``argparse 的旗標定義（攤平成 key/opts 序列，直接 ;flags splice 進 ap/argparse）。``
  ["system"      {:kind :option :short "s" :help "system 訊息（可省略）。"}
   "model"       {:kind :option :short "m" :help "覆寫送給伺服器的 model 名稱。"}
   "base"        {:kind :option :short "b" :help "proxy base URL，預設 http://127.0.0.1:4000。"}
   "url"         {:kind :option :short "u"
                  :help "完整的 chat completions 網址，給了就完全繞過 --base（例如 LM Studio 的 http://127.0.0.1:1234/v1/chat/completions）。"}
   "api-key"     {:kind :option :help "覆寫 Authorization: Bearer 的 token。"}
   "header"      {:kind :accumulate
                  :help "額外的 request header，寫成 名字:值，可重複給。"}
   "endpoints"   {:kind :accumulate
                  :help "載入 endpoint 設定檔（.janet 資料字面值或 .json），可重複給。"}
   "temperature" {:kind :option :help "取樣溫度，覆寫 endpoint 自己的 :params。"}
   "max-tokens"  {:kind :option :help "回應長度上限，覆寫 endpoint 自己的 :params。"}
   "top-p"       {:kind :option :help "nucleus sampling 的 top_p。"}
   "param"       {:kind :accumulate
                  :help "任意請求參數，寫成 名字=值（值會自動轉數字／true／false／null），可重複給。"}
   "image"       {:kind :accumulate :short "i"
                  :help "圖檔路徑或 http(s)/data URL，可重複給。⚠ 要挑吃圖的 endpoint。"}
   "tools"       {:kind :flag :short "t" :help "啟用內建示範工具（now／get_weather），跑多輪 tool loop。"}
   "rounds"      {:kind :option :help "tool loop 最多打幾輪，預設 8。"}
   "list"        {:kind :flag :short "l" :help "列出所有 endpoint（內建與自訂）就結束。"}
   :default      {:kind :accumulate
                  :help "第一個是 endpoint 名字，其餘串成 prompt。"}])

(defn parse-args
  ``解析命令列。argv 的第 0 個是執行檔自己（跟 (dyn :args) 一樣的形狀）。
  解析失敗或 --help 時回 nil（usage 已由 argparse 自己印出）。``
  [argv]
  (with-dyns [:args argv]
    (ap/argparse usage ;flags)))
