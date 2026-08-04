# llm-http 範例 ④ —— tool loop：自訂工具、多個工具、handler 丟例外時的行為。
#
# 一輪完整的 tool use（with-tools 幫你轉的圈）：
#   1. 送 messages ＋ tools 宣告
#   2. 模型回 tool_calls  → 把**整則 assistant message 原樣接回歷史**
#   3. 本地執行每個 call → push @{:role "tool" :tool_call_id … :content 結果}
#   4. 再送一次，模型拿結果作答；還要工具就回到 2（最多 :max-rounds 輪）
#
# ★ 本檔的工具都是**無害**的：算數學、查一張寫死的表、故意丟例外。
#   不碰檔案、不執行指令——example 就該這樣。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   * OpenAI 相容伺服器在跑（預設 litellm proxy http://127.0.0.1:4000）
#   * ⚠ **模型本身要支援 tool calling**。小模型常常「假裝」有呼叫工具（把 JSON
#     直接寫在 content 裡），那時 tool_calls 是空的、loop 一輪就結束。
#     看到答案怪怪的又沒有「→ 工具」的 trace，多半就是這個。
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/04-tools.janet [endpoint 名字]

(import ../../modules/llm-http/init :as llm)

(def hint "\n提示：後端沒起來。先起 litellm proxy（見 01-minimal.janet 檔頭），位址用 127.0.0.1。")

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)                       # ★ 先把 stdout 吐出來，錯誤才不會插隊到前面
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

# ── 工具宣告：就是一份 JSON schema，用 Janet 的 struct 直接寫 ────────
(def tools
  [(llm/tool-spec "add" "把兩個數字相加"
                  {:type "object"
                   :properties {:a {:type "number" :description "第一個加數"}
                                :b {:type "number" :description "第二個加數"}}
                   :required ["a" "b"]})

   (llm/tool-spec "city_population" "查詢某座城市的人口（單位：萬人）"
                  {:type "object"
                   :properties {:city {:type "string" :description "城市名稱，繁體中文"}}
                   :required ["city"]})

   (llm/tool-spec "always_fails" "一個一定會壞掉的工具，用來看錯誤怎麼傳回模型"
                  {:type "object" :properties {} :required []})])

# ── handler：工具名 → Janet 函式 ────────────────────────────────────
# 函式收一張**已經解好的參數 table**（key 是 keyword），
# 回字串就原樣送回模型，回其他東西會被 encode 成 JSON。
(def populations {"台北" 246 "台中" 285 "高雄" 273})

(def handlers
  {"add" (fn [args]
           # ⚠ 參數是模型填的，型別不保證：這裡自己 default 一下比較安全
           (+ (get args :a 0) (get args :b 0)))

   "city_population" (fn [args]
                       (def city (get args :city ""))
                       (if-let [p (get populations city)]
                         {:city city :population_10k p}
                         # 查不到就老實回一句話，模型看得懂
                         (string "查無此城市：" city
                                 "（目前只有 " (string/join (keys populations) "、") "）")))

   # ★ handler 自己丟例外**不會**炸掉整條 loop：
   #   with-tools 會把錯誤字串當成「工具結果」送回模型，讓它有機會改參數重試。
   "always_fails" (fn [_] (error "這個工具壞掉了（示範用）"))})

(defn trace [name args result]
  (eprintf "  → 工具 %s(%s)\n  ← %s"
           name
           (string/join (seq [[k v] :pairs args]
                          (string/format "%s=%s" k (if (bytes? v) (string v) (string/format "%q" v))))
                        " ")
           result))

(defn run-case [cfg title prompt]
  (printf "\n── %s ──" title)
  (printf "問：%s" prompt)
  (when-let [out (attempt title
                          |(llm/with-tools cfg
                                           @[@{:role "user" :content prompt}]
                                           tools handlers
                                           :system "你只用繁體中文回答。需要算數或查資料時一律用工具，不要自己猜。"
                                           :max-rounds 6
                                           :trace trace))]
    (printf "答：%s" (or (out :text) "（撞到 max-rounds，沒有最終答案）"))
    (printf "（共 %d 輪，exhausted=%q，歷史 %d 則）"
            (out :rounds) (out :exhausted) (length (out :messages)))))

(defn main [& args]
  (def cfg (llm/endpoint (get args 1 "local")))
  (unless cfg (eprint "沒有這個 endpoint") (os/exit 1))

  # ① 單一工具
  (run-case cfg "單一工具" "1234 加 5678 是多少？")

  # ② 一句話裡要用到兩個不同的工具
  (run-case cfg "多個工具" "台北跟高雄的人口加起來是多少萬人？兩步都要用工具。")

  # ③ 工具查不到東西 —— 回一句人話，模型會轉述
  (run-case cfg "查不到" "台南的人口是多少？")

  # ④ handler 丟例外 —— 錯誤被當成工具結果送回模型，loop 不會掛
  (run-case cfg "handler 丟例外" "呼叫 always_fails 這個工具，然後告訴我發生什麼事。")

  (print "\n★ 重點：handler 丟例外時，with-tools 會把「工具執行失敗：…」當成工具結果送回模型，")
  (print "  整條 loop 不會掛掉——模型通常看得懂錯誤訊息並改用別的做法。"))
