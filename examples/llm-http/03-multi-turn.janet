# llm-http 範例 ③ —— 多輪對話：自己維護 messages 陣列。
#
# ★ 這條線**沒有 session、沒有 conversation id**：chat completion 是無狀態的，
#   「記得剛才講過什麼」完全靠你**每次把整段歷史重送一次**。
#   所以多輪對話的本體就是一個你自己拿著的 Janet 陣列。
#
# ⚠ 歷史會愈滾愈長 = 每輪的 token 愈花愈多。真的要長對話請自己截斷／摘要
#   （最簡單的做法：保留 system ＋ 最後 N 則，本檔最後有示範）。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   要有 OpenAI 相容伺服器在跑（預設 litellm proxy http://127.0.0.1:4000）：
#     uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \
#            litellm --config modules/llm-http/lite.yaml --port 4000
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/03-multi-turn.janet [endpoint 名字]

(import ../../modules/llm-http/init :as llm)

(def hint "\n提示：後端沒起來。先起 litellm proxy（見 01-minimal.janet 檔頭），位址用 127.0.0.1。")

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)                       # ★ 先把 stdout 吐出來，錯誤才不會插隊到前面
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

# 這一輪要問的三句話：第二、三句都刻意依賴前面的上下文，
# 模型答得出來就代表歷史真的有帶到。
(def turns
  ["我叫小明，我養了一隻叫嚕嚕的貓。"
   "我的貓叫什麼名字？"
   "牠是什麼動物？"])

(defn say
  ``送出一輪：把 user 訊息 push 進歷史 → 打一次 → 把 assistant 的回答也 push 回去。
  ★ 回答一定要 push 回歷史，否則下一輪模型就「忘了自己講過什麼」。``
  [cfg history text]
  (array/push history @{:role "user" :content text})
  (def res (llm/chat cfg history))
  (def msg (llm/reply-message res))
  (array/push history msg)                    # ★ 整則原樣接回去
  (get msg :content))

(defn main [& args]
  (def cfg (llm/endpoint (get args 1 "local")))
  (unless cfg (eprint "沒有這個 endpoint") (os/exit 1))

  # 歷史就是一個普通的陣列；第一則放 system（可省略）
  (def history @[@{:role "system" :content "你只用繁體中文回答，每次不超過 20 個字。"}])

  (var stopped false)
  (each t turns
    (unless stopped
      (printf "\n我 → %s" t)
      (def answer (attempt "多輪對話" |(say cfg history t)))
      (if answer
        (printf "AI ← %s" answer)
        (set stopped true))))

  (unless stopped
    (printf "\n── 歷史現在有 %d 則 ──" (length history))
    (each m history
      (printf "  %-9s %s" (get m :role)
              (let [c (string (or (get m :content) ""))]
                (if (> (length c) 60) (string (string/slice c 0 60) "…") c))))

    # ── 截斷：長對話一定要做的事 ──────────────────────────────────
    # 最簡單的策略：留住 system（第一則）＋ 最後 4 則。
    (def keep 4)
    (def trimmed
      (if (<= (length history) (inc keep))
        history
        (array/concat @[(first history)] (slice history (- keep)))))
    (printf "\n截斷後剩 %d 則（保留 system ＋ 最後 %d 則）——下一輪就送這份。"
            (length trimmed) keep)))
