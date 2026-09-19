# agent 範例 ① —— 十行組一個能讀檔、算數、抓網頁的 agent，跟它說一句話。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   要有一台 OpenAI 相容的伺服器在跑（見 examples/llm-http/01-minimal.janet 的說明）；
#   沒起來也不會噴 stacktrace，會印「連不上」提示然後正常結束（exit 0）。
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/agent/01-quickstart.janet
#   janet examples/agent/01-quickstart.janet local "這個資料夾有什麼檔案？"

(import ../../modules/agent/init :as ag)

(def hint
  (string "\n提示：後端沒起來。起 litellm proxy 或 LM Studio，見 "
          "examples/llm-http/01-minimal.janet 檔頭的說明。"))

(defn main [& args]
  (def name (get args 1 "local"))
  (def question (get args 2 "這個資料夾有哪些檔案？用一句話回答。"))

  # 十行組一個 agent：endpoint 名字 ＋ 預設安全的工具箱（只讀、限本資料夾）
  (def [ok1 a] (protect
    (ag/make-agent {:endpoint name
                     :system "你是一個簡短回答問題的助理。"
                     :tools (ag/default-tools :root ".")
                     :trace (ag/stderr-tracer)})))
  (unless ok1
    (eprintf "組不出 agent：%s" a)
    (os/exit 1))

  (printf "endpoint = %s" name)
  (printf "問       = %s\n" question)
  (flush)

  (def [ok2 out] (protect (ag/run a question)))
  (if ok2
    (print "答 = " (out :text))
    (do (flush)
        (eprintf "呼叫失敗：%s" out)
        (when (string/find "連不上" (string out)) (eprint hint)))))
