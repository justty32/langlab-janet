# llm-http 範例 ⑪ —— 結構化輸出：要模型回 JSON，拿回解好的 Janet 資料。
#
# 兩層保險：
#   1. 送 response_format（json_object 或 json_schema）——認得的伺服器會強制輸出合法 JSON
#   2. 回來的字串**自己解**（parse-json-reply）——不認得的伺服器會靜靜無視①，這一層才是真的保證
# 解不出來會丟中文錯誤並附上模型原文，不會給你一個假的空表。
#
# 前半段是純函式（不需要後端）：看 response_format 長怎樣、parse-json-reply 怎麼剝圍欄。
# 後半段 ask-json 真的打後端，沒起來會印提示。
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/11-json-output.janet [endpoint 名字]

(import ../../modules/llm-http/init :as llm)

(def hint "\n提示：後端沒起來。先起 litellm proxy（見 01-minimal.janet 檔頭），位址用 127.0.0.1。")

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

(def schema
  "一份普通的 JSON schema，用 Janet 的 struct 寫。"
  {:type "object"
   :properties {:city    {:type "string"}
                :country {:type "string"}
                :population_millions {:type "number"}}
   :required ["city" "country" "population_millions"]
   :additionalProperties false})

(defn main [& args]
  (def name (get args 1 "local"))

  # ── ① response_format 長怎樣（純函式）────────────────────────────
  (print "── ① response_format 兩種寫法 ──")
  (printf "  json_object：%q" {:type "json_object"})
  (printf "  json_schema：%q" (llm/json-schema-format "city" schema))
  (def cfg (llm/endpoint name))
  (when cfg
    (printf "  進 payload 之後：%q"
            ((llm/build-payload cfg @[] :response-format {:type "json_object"}) :response_format)))

  # ── ② parse-json-reply：圍欄剝掉、解不出來講清楚（純函式）──────────
  (print "\n── ② parse-json-reply ──")
  (printf "  乾淨的 JSON     → %q" (llm/parse-json-reply `{"a":1,"b":[1,2]}`))
  (printf "  包在 ```json 裡 → %q" (llm/parse-json-reply "```json\n{\"a\":1}\n```"))
  (def [ok e] (protect (llm/parse-json-reply "我覺得答案是 42")))
  (printf "  不是 JSON       → 丟錯：%s" (first (string/split "\n" (string e))))

  # ── ③ 真的問：ask-json ─────────────────────────────────────────────
  (print "\n── ③ ask-json ──")
  (unless cfg
    (eprintf "沒有這個 endpoint：%s" name)
    (os/exit 1))
  # 沒給 :schema → json_object，形狀在 prompt 裡講
  (when-let [j (attempt "ask-json（json_object）"
                        |(llm/ask-json cfg "台北在哪個國家？人口幾百萬？回 JSON，key 用 city／country／population_millions"
                                       "只回 JSON 物件，不要解釋"))]
    (printf "  → %q" j)
    (printf "  (j :city) = %q" (get j :city)))
  # 給 :schema → json_schema（⚠ 不是每家都吃 strict schema；OpenRouter 有些模型會無視）
  (when-let [j (attempt "ask-json（json_schema）"
                        |(llm/ask-json cfg "東京的資料" nil nil :schema schema))]
    (printf "  → %q" j)))
