# llm-http 範例 ② —— system prompt 的三種給法。
#
# 同一件事（「叫模型只用某種方式回答」）有三個入口，用途不同：
#   ① ask 的第二個參數        最省事，單次問答用這個
#   ② with-tools 的 :system   跑 tool loop 又懶得自己組 messages 時用
#   ③ 自己組 messages 陣列    要精細掌控整段歷史時用（多輪對話一定走這條）
#
# ⚠ ② 的 :system **只在 messages 第一則還不是 system 時才會插入**——
#   已經自己放了就會被忽略，避免一次送兩則 system 讓模型無所適從。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   要有 OpenAI 相容伺服器在跑（預設 litellm proxy http://127.0.0.1:4000）：
#     uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \
#            litellm --config modules/llm-http/lite.yaml --port 4000
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/02-system-prompt.janet [endpoint 名字]

(import ../../modules/llm-http/init :as llm)

(def hint "\n提示：後端沒起來。先起 litellm proxy（見 01-minimal.janet 檔頭），位址用 127.0.0.1。")

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)                       # ★ 先把 stdout 吐出來，錯誤才不會插隊到前面
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

(def system-text "你是海盜。所有回答都要以「啊哈！」開頭，而且只能用繁體中文。")
(def question "1 + 1 等於多少？")

(defn main [& args]
  (def cfg (llm/endpoint (get args 1 "local")))
  (unless cfg (eprint "沒有這個 endpoint") (os/exit 1))

  # ── ① ask 的第二個參數 ────────────────────────────────────────────
  # 簽名是 (ask cfg prompt &opt system images)，所以只要往後多給一個字串。
  (print "── ① ask 的第二個參數 ──")
  (when-let [a (attempt "ask + system" |(llm/ask cfg question system-text))]
    (print a))

  # ── ② with-tools 的 :system ───────────────────────────────────────
  # tool loop 吃的是完整的 messages 陣列，:system 是「幫你插到最前面」的便利參數。
  # 這裡刻意不給任何工具（空陣列），純粹示範 :system 的位置。
  (print "\n── ② with-tools 的 :system ──")
  (when-let [out (attempt "with-tools + :system"
                          |(llm/with-tools cfg
                                           @[@{:role "user" :content question}]
                                           [] {}
                                           :system system-text))]
    (print (out :text))
    # 看一下它到底往 messages 裡塞了什麼
    (printf "（歷史第一則的 role = %s）" (get-in out [:messages 0 :role])))

  # ⚠ 已經自己放了 system 時，:system 會被忽略——這裡驗給你看（不必連線）
  (def out2-messages
    @[@{:role "system" :content "我自己放的 system"}
      @{:role "user"   :content question}])
  (print "\n⚠ messages 第一則已經是 system 時，:system 參數會被忽略：")
  (printf "   自己放的是「%s」，:system 給的「%s」不會蓋掉它。"
          (get-in out2-messages [0 :content]) system-text)

  # ── ③ 自己組 messages ─────────────────────────────────────────────
  # 最囉唆但也最可控：messages 就是一個普通的 Janet 陣列，你想放幾則就幾則。
  (print "\n── ③ 自己組 messages ──")
  (def messages @[@{:role "system" :content system-text}
                  @{:role "user"   :content question}])
  (when-let [res (attempt "自組 messages" |(llm/chat cfg messages))]
    (print (llm/reply-text res)))

  (print "\n★ 結論：單次問答用 ①，tool loop 用 ②，要掌控歷史（多輪）用 ③——見 03-multi-turn.janet。"))
