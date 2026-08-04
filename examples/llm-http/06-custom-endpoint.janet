# llm-http 範例 ⑥ —— 自訂 endpoint 的四種寫法。
#
# 內建只有 local／deepseek／claude／openrouter 四筆，但你**不需要改 repo 原始碼**
# 就能加自己的。四條路，由輕到重：
#
#   ① inline table       —— 完全不註冊，當場給一張 table 就是一個 endpoint
#   ② define-endpoint    —— 註冊成有名字的，之後照舊用名字取
#   ③ 設定檔             —— 寫進 ~/.config/llm-http/endpoints.janet，自動載入
#   ④ 直接指定 :url      —— **繞過 litellm proxy**，直打任何 OpenAI 相容伺服器
#
# ★ 本檔前半段（①②③的組法）**不用連線就跑得完**，最後才真的送一次。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   組 endpoint 那幾段不需要任何後端。最後「真的送出去」那段才需要：
#     * litellm proxy（http://127.0.0.1:4000），或
#     * LM Studio（http://127.0.0.1:1234）—— 走 ④ 那條就不用 proxy 了
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/06-custom-endpoint.janet

(import ../../modules/llm-http/init :as llm)

(def hint
  (string "\n提示：後端沒起來。二選一：\n"
          "  (a) 起 litellm proxy：uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \\\n"
          "        litellm --config modules/llm-http/lite.yaml --port 4000\n"
          "  (b) 開 LM Studio 並載入一個模型（走本檔 ④ 那條，不需要 proxy）\n"
          "⚠ 位址一律寫 127.0.0.1 不要寫 localhost（::1 陷阱，見 FINDINGS.md 第五節）。"))

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)                       # ★ 先把 stdout 吐出來，錯誤才不會插隊到前面
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

(defn show [label cfg]
  (printf "  %-10s model=%-22s url=%s" label (cfg :model) (cfg :url))
  (when-let [p (cfg :params)]
    (printf "             預設參數 %s"
            (string/join (seq [[k v] :pairs p] (string/format "%s=%q" k v)) " "))))

(defn main [& _]

  # ── ① inline table：完全不註冊 ────────────────────────────────────
  # endpoint 的第一個參數除了名字字串，也吃 table／struct。
  # 缺 :model 之類的問題會**當場**丟中文錯誤，不會等到打 HTTP 才炸。
  (print "── ① inline table（不註冊）──")
  (def inline (llm/endpoint {:model   "qwen3"
                             :base    "http://127.0.0.1:4000"
                             :params  {:temperature 0.2 :max_tokens 256}
                             :vision? false
                             :note    "臨時用一次，不想污染 registry"}))
  (show "inline" inline)
  (printf "  registry 裡還是只有：%s" (string/join (llm/endpoint-names) "、"))

  (def [ok e] (protect (llm/endpoint {:base "http://127.0.0.1:4000"})))
  (printf "  少寫 :model 的話：%s" (if ok "（居然沒錯？）" e))

  # ── ② define-endpoint：註冊成有名字的 ─────────────────────────────
  (print "\n── ② define-endpoint（註冊）──")
  (llm/define-endpoint "qwen"
                       {:model   "qwen3"
                        :params  {:temperature 0.2}
                        :note    "本機 proxy 上的 Qwen，固定低溫"})
  (show "qwen" (llm/endpoint "qwen"))
  (printf "  現在 registry 有：%s" (string/join (llm/endpoint-names) "、"))
  (printf "  來源標記：%q（--list 會拿它分內建／自訂）" (llm/endpoint-source "qwen"))
  # 取的時候還可以再疊 overrides，:params 是**疊加**不是取代
  (show "qwen+ov" (llm/endpoint "qwen" {:params {:max_tokens 64}}))

  # ── ③ 設定檔：不必改 repo、也不必 commit 自己的設定 ────────────────
  # 這裡當場寫一份暫存設定檔示範；實際使用請放到自動探測得到的位置：
  #   $LLM_HTTP_ENDPOINTS → $XDG_CONFIG_HOME/llm-http/endpoints.janet
  #                       → ~/.config/llm-http/endpoints.janet
  # ★ 檔案內容是**資料字面值**，只 parse 不 eval（裡面寫程式碼也不會被執行）。
  (print "\n── ③ 設定檔 ──")
  (def path (string (or (os/getenv "TMPDIR") "/tmp") "/llm-http-example-endpoints.janet"))
  (spit path
        ``{"from-file" {:model  "local"
                        :base   "http://127.0.0.1:4000"
                        :params {:temperature 0.7}
                        :note   "從設定檔載進來的"}}``)
  (printf "  寫了一份：%s" path)
  (def names (llm/load-endpoints! path))
  (printf "  載入 %s" (string/join names "、"))
  (show "from-file" (llm/endpoint "from-file"))
  (printf "  來源標記：%s" (llm/endpoint-source "from-file"))
  (printf "  自動探測會依序找：%s" (string/join (llm/config-candidates) "、"))
  (printf "  範本（含中文註解）：modules/llm-http/endpoints.example.janet")

  # 壞掉的設定檔給的是中文訊息，不是 stacktrace
  (def bad (string path ".bad"))
  (spit bad `{"a" {:model 1}}`)
  (def [ok2 e2] (protect (llm/load-endpoints! bad)))
  (printf "  故意寫壞：%s" (if ok2 "（居然沒錯？）" e2))
  (os/rm bad)
  (os/rm path)

  # ── ④ 直接指定 :url：繞過 proxy，直打 OpenAI 相容伺服器 ────────────
  # LM Studio、vLLM、llama.cpp 的 server… 都是 OpenAI 相容的，
  # 給了 :url 就完全不看 :base，也就不需要 litellm 擋在前面。
  # ⚠ spork/http **沒有 TLS**，:url 只能是 http:// 不能是 https://。
  (print "\n── ④ 直接指定 :url（繞過 proxy）──")
  (def lmstudio (llm/endpoint {:model   "google/gemma-4-e4b"
                               :url     "http://127.0.0.1:1234/v1/chat/completions"
                               :api-key "lm-studio"
                               :vision? true
                               :note    "直接打 LM Studio"}))
  (show "lmstudio" lmstudio)

  # ── 真的送一次（哪一條通就用哪一條）────────────────────────────────
  (print "\n── 真的送出去 ──")
  (def question "回一個字：好")
  (var answered false)
  (each [label cfg] [["④ 直打 LM Studio" lmstudio]
                     ["② 註冊過的 qwen" (llm/endpoint "qwen")]
                     ["內建的 local"     (llm/endpoint "local")]]
    (unless answered
      (printf "\n試 %s（%s）…" label (cfg :url))
      (when-let [a (attempt label |(llm/ask cfg question))]
        (printf "答 = %s" a)
        (set answered true))))

  (unless answered
    (print "\n（三條都沒通，上面的提示告訴你怎麼把後端起起來）"))

  # 收拾：把示範註冊的拿掉，免得 REPL 裡殘留
  (llm/undefine-endpoint! "qwen")
  (llm/undefine-endpoint! "from-file"))
