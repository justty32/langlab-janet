# llm-http 範例 ① —— 最小問答：兩行就能問一句話。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   要有一台 **OpenAI 相容的伺服器**在跑，二選一：
#     (a) litellm proxy（預設 http://127.0.0.1:4000）
#         cd <janet-lab 根目錄>
#         uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \
#                litellm --config modules/llm-http/lite.yaml --port 4000
#         ⚠ fastapi<0.119 這個 pin 不能省（見 ../../FINDINGS.md 第三節）
#         而且 local 這條線後面接的是本機 LM Studio，LM Studio 也要開著。
#     (b) 直接打 LM Studio（不用 proxy）—— 見 06-custom-endpoint.janet
#
#   沒起來也不會噴 stacktrace，會告訴你「連不上」並印出上面這段提示。
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/01-minimal.janet
#   janet examples/llm-http/01-minimal.janet deepseek "用一句話介紹 Janet"

(import ../../modules/llm-http/init :as llm)

(def hint
  (string "\n提示：後端沒起來。起 litellm proxy：\n"
          "  uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \\\n"
          "         litellm --config modules/llm-http/lite.yaml --port 4000\n"
          "或改用 --url 直接打 LM Studio，見 06-custom-endpoint.janet。\n"
          "⚠ 位址一律寫 127.0.0.1 不要寫 localhost（::1 陷阱，見 FINDINGS.md 第五節）。"))

(defn attempt
  ``跑一段可能失敗的呼叫：成功回結果，失敗印一行看得懂的中文並回 nil。
  ★ 這些 example 都用這招——protect 把例外接下來，讀者看到的是提示不是 stacktrace。``
  [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)                       # ★ 先把 stdout 吐出來，錯誤才不會插隊到前面
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

(defn main [& args]
  (def name   (get args 1 "local"))
  (def prompt (get args 2 "台灣最高的山是哪座？用一句話回答。"))

  # ① 取一份 endpoint 設定：一張普通的 table，裡面有 :model :url :api-key…
  (def cfg (llm/endpoint name))
  (unless cfg
    (eprintf "沒有這個 endpoint：%s（可用：%s）"
             name (string/join (llm/endpoint-names) "、"))
    (os/exit 1))

  (printf "endpoint = %s" name)
  (printf "打哪裡   = %s" (cfg :url))
  (printf "model    = %s" (cfg :model))
  (printf "問       = %s\n" prompt)

  # ② 一行式問答：給 prompt，拿字串回來
  (when-let [answer (attempt "問答" |(llm/ask cfg prompt))]
    (print "答 = " answer)))
