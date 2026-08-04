# llm-http：CLI 那一層的純函式 —— 不 os/exit、不碰網路。
#
# run 本身會 os/exit 所以不測；能測的都被拆成純函式了（cli-args.janet／cli-list.janet）。

(import ../modules/llm-http/init :as llm)
(import ../modules/llm-http/cli :as cli)
(import ./util :as u)

(llm/reset-endpoints!)

# ── 命令列字串 → Janet 值 ───────────────────────────────────────────
(assert (= 0.3 (cli/coerce-value "0.3")) "數字字串轉成數字")
(assert (= true (cli/coerce-value "true")))
(assert (= false (cli/coerce-value "false")))
(assert (= "auto" (cli/coerce-value "auto")) "其餘原樣當字串")
(assert (deep= ["a" "b=c"] (cli/parse-kv "a=b=c" "=" "--param")) "只切第一個分隔符")
(assert (string/find "格式要是" (u/err-of |(cli/parse-kv "沒有等號" "=" "--param"))))
(assert (deep= @{:seed 7 :stop "END"} (cli/param-table @["seed=7" "stop=END"])))
(assert (deep= @{"x-a" "1" "x-url" "http://127.0.0.1:1"}
                (cli/header-table @["x-a: 1" "x-url: http://127.0.0.1:1"]))
        "header 的值裡還可以有冒號")

(def res1 (cli/parse-args @["llm-http" "--temperature" "0.4" "--param" "seed=7"
                            "--param" "temperature=0.9" "local" "嗨"]))
(assert res1 "命令列解得開")
(assert (deep= @{:temperature 0.4 :seed 7} (cli/request-params res1))
        "--temperature 比通用的 --param 具體，蓋得掉它")
(assert (string/find "要是數字"
                     (u/err-of |(cli/request-params (cli/parse-args @["x" "--temperature" "熱"])))))

# ── resolve-endpoint ────────────────────────────────────────────────
# 名字在 registry 裡
(def r-local (cli/resolve-endpoint (cli/parse-args @["x" "-m" "qwen" "local" "嗨"]) "local"))
(assert (= "qwen" (r-local :model)) "--model 覆寫得了")
# 名字不在 registry，但給了 --url ＋ --model → 當場組一個臨時 endpoint
(def r-adhoc
  (cli/resolve-endpoint
    (cli/parse-args @["x" "--url" "http://127.0.0.1:1234/v1/chat/completions"
                      "-m" "qwen3" "lmstudio" "嗨"])
    "lmstudio"))
(assert (= "http://127.0.0.1:1234/v1/chat/completions" (r-adhoc :url)))
(assert (= "qwen3" (r-adhoc :model)))
(assert (= "lmstudio" (r-adhoc :name)))
# 什麼都沒給就回 nil，由 run 去報「沒有這個 endpoint」
(assert (nil? (cli/resolve-endpoint (cli/parse-args @["x" "沒這個" "嗨"]) "沒這個")))

# ── --list 的輸出要分得出內建與自訂 ─────────────────────────────────
(llm/define-endpoint "我的" {:model "mine"})
(def listed (cli/list-text))
(assert (string/find "內建 endpoint" listed))
(assert (string/find "自訂 endpoint" listed))
(assert (string/find "我的" listed))
(assert (string/find "define-endpoint 註冊的" listed) "自訂的要標出來源")
(llm/reset-endpoints!)
(assert (string/find "自訂 endpoint：（沒有）" (cli/list-text)))

(print "llm-http CLI 測試通過 ✓")
