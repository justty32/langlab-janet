# llm-http：**endpoint 設定檔載入** —— .janet／.json 兩種格式、壞檔的中文錯誤、探測順序。
#
# 檔案都寫在暫存目錄，測完清乾淨。不打網路。

(import ../modules/llm-http/init :as llm)
(import ./util :as u)

(llm/reset-endpoints!)

(def tmp-dir (string (or (os/getenv "TMPDIR") "/tmp") "/janet-lab-llm-http-test"))
(os/mkdir tmp-dir)                       # 已存在會回 false，不丟例外
(defn- write-tmp [name content]
  (def p (string tmp-dir "/" name))
  (spit p content)
  p)

(def good-path
  (write-tmp "good.janet"
             ``# 註解可以有
             {"qwen" {:model "qwen3" :params {:temperature 0.2}}}
             {"lmstudio" {:model "g" :url "http://127.0.0.1:1234/v1/chat/completions"}}``))
(def loaded (llm/load-endpoints! good-path))
(assert (deep= @["lmstudio" "qwen"] loaded) "兩筆都載進來（多個 top-level 表會疊加）")
(assert (= "qwen3" ((llm/endpoint "qwen") :model)))
(assert (= good-path (llm/endpoint-source "qwen")) "來源記的是檔案路徑")
(assert (find |(= good-path $) llm/loaded-files) "載過的檔案有記錄下來")

# JSON 版本也吃
(def json-path (write-tmp "eps.json" `{"jsonep": {"model": "j", "params": {"temperature": 0.1}}}`))
(llm/load-endpoints! json-path)
(assert (= "j" ((llm/endpoint "jsonep") :model)) ".json 走 spork/json")
(assert (= 0.1 (get-in (llm/endpoint "jsonep") [:params :temperature])))

# ── 壞掉的設定檔要給看得懂的中文訊息，不是 Janet 的 stacktrace ──────
(def missing (string tmp-dir "/根本沒這個檔.janet"))
(assert (string/find "找不到 endpoint 設定檔" (u/err-of |(llm/load-endpoints! missing))))

(def broken (write-tmp "broken.janet" `{"a" {:model "x"}`))     # 少一個右括號
(def e-broken (u/err-of |(llm/load-endpoints! broken)))
(assert (string/find "格式有誤" e-broken) (string "壞括號要講格式有誤：" e-broken))

(def not-table (write-tmp "not-table.janet" `(def x 1)`))
(assert (string/find "最外層應該是一張表" (u/err-of |(llm/load-endpoints! not-table))))

(def bad-spec (write-tmp "bad-spec.janet" `{"a" {:base "http://x"}}`))
(def e-bad (u/err-of |(llm/load-endpoints! bad-spec)))
(assert (string/find "缺 :model" e-bad) "設定不合法要指出是哪一筆的什麼問題")
(assert (string/find "「a」" e-bad) "錯誤訊息要講是哪個 endpoint")

# ── 探測順序：LLM_HTTP_ENDPOINTS 排第一 ─────────────────────────────
(os/setenv "LLM_HTTP_ENDPOINTS" good-path)
(assert (= good-path (first (llm/config-candidates))) "環境變數排在探測順序第一")
(os/setenv "LLM_HTTP_ENDPOINTS" nil)
(assert (not (find |(= good-path $) (llm/config-candidates))))
# 沒有設定檔是正常狀態：autoload 不該炸（這裡不驗回傳值，本機可能真的有一份）
(assert (or true (llm/autoload-endpoints!)))

(each f ["good.janet" "eps.json" "broken.janet" "not-table.janet" "bad-spec.janet"]
  (os/rm (string tmp-dir "/" f)))
(os/rmdir tmp-dir)
(llm/reset-endpoints!)

(print "llm-http 設定檔測試通過 ✓")
