# 結構化輸出 —— ask-json：要模型回 JSON，並把它解成 Janet table 回來。
#
# 兩種要法（都走 chat 的 :response-format，OpenAI 的 response_format 欄位）：
#   {:type "json_object"}                          只保證是合法 JSON，形狀自己在 prompt 裡講
#   {:type "json_schema" :json_schema {:name … :schema {…} :strict true}}  照 schema 出
# :api :anthropic 那條會由 anthropic-req 轉成 output_config.format（json_object 沒有對應，
# 改塞一句 system 提示）。
#
# ⚠ 不是每個後端都認 response_format：LM Studio 認、litellm 看後面那家、OpenRouter 有些模型
#   **靜靜無視**。所以這裡不信任伺服器，拿到字串一律自己解；解不出來丟中文錯誤並附原文。
# ⚠ 小模型常把 JSON 包在 ```json 圍欄裡，解之前先剝掉（json_object 模式下理論上不會，實務上會）。

(import spork/json)
(import ./chat :as conv)

(defn strip-fence
  "去掉 ```json … ``` 或 ``` … ``` 圍欄；沒有圍欄原樣回。"
  [s]
  (def t (string/trim s))
  (if (string/has-prefix? "```" t)
    (let [first-nl (or (string/find "\n" t) (length t))
          body (string/slice t first-nl)
          end (string/find "```" body)]
      (string/trim (if end (string/slice body 0 end) body)))
    t))

(defn parse-json-reply
  ``把模型回的文字解成 Janet 資料（key 是 keyword）；解不出來丟中文錯誤並附上原文。``
  [text]
  (def cleaned (strip-fence (string text)))
  (def [ok v] (protect (json/decode cleaned true)))
  (unless ok
    (error (string "模型回的不是合法 JSON：" v "\n原文：" (string/trim (string text)))))
  v)

(defn json-schema-format
  ``組一個 json_schema 型的 response_format。name 是給伺服器看的名字，schema 是 JSON schema。
  strict 預設 true（OpenAI 才會嚴格照 schema）。``
  [name schema &opt strict]
  (default strict true)
  {:type "json_schema"
   :json_schema {:name name :schema schema :strict strict}})

(defn ask-json
  ``跟 ask 一樣問一句，但要求模型回 JSON，並回**解好的** Janet 資料。

  :schema  可省略；給了就走 json_schema（會用 json-schema-format 包起來，name 預設 "reply"），
           沒給就走 json_object。
  其餘具名參數（:temperature／:max-tokens／:params／:extra／:retry）原樣轉給 ask。

  (ask-json cfg "把「台北」翻成三種語言，key 用語言代碼" "只回 JSON")
  # => @{:en "Taipei" :ja "台北" …}``
  [cfg prompt &opt system images &named schema temperature max-tokens top-p extra params retry]
  (def fmt (if schema (json-schema-format "reply" schema) {:type "json_object"}))
  (def text (conv/ask cfg prompt system images
                      :temperature temperature :max-tokens max-tokens :top-p top-p
                      :extra extra :params params :retry retry :response-format fmt))
  (parse-json-reply text))
