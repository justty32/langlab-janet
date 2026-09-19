# 記憶的存檔／讀回 —— JSON 一個檔，人看得懂、別的語言也讀得了。
#
# 檔案形狀：
#   {"version": 1, "max-turns": 20, "max-chars": 48000, "min-turns": 1,
#    "messages": [{"role": "system", "content": "…"}, …]}
#
# ⚠ spork/json 會把非 ASCII 逃逸成 \uXXXX（"台北" 存成 "台北"），讀回來是對的，
#   只是用 cat 看檔案時中文不直觀。要人讀就 (memory-io/load …) 再印。
# ⚠ json/decode 第二個參數給 true，key 才會是 keyword（跟記憶裡的訊息形狀一致）。

(import spork/json)
(import ./memory :as mem)

(def file-version 1)

(defn to-data
  "記憶 → 可以 json/encode 的 table。"
  [m]
  @{:version file-version
    :max-turns (m :max-turns)
    :max-chars (m :max-chars)
    :min-turns (m :min-turns)
    :messages (m :messages)})

(defn from-data
  "json/decode 出來的 table → 記憶。缺欄位就用 make-memory 的預設值。"
  [data]
  (unless (dictionary? data) (error "對話檔的內容不是一個 JSON 物件"))
  (def msgs (get data :messages))
  (unless (indexed? msgs) (error "對話檔缺 messages 陣列"))
  (def m (mem/make-memory :max-turns (get data :max-turns)
                          :max-chars (get data :max-chars)
                          :min-turns (get data :min-turns)))
  (each msg msgs
    (unless (and (dictionary? msg) (get msg :role))
      (error (string "對話檔裡有一則訊息沒有 role：" (string/format "%q" msg))))
    (mem/append! m msg))
  m)

(defn save!
  "把記憶寫進 path（整檔覆蓋）。回傳 path。"
  [m path]
  (spit path (json/encode (to-data m)))
  path)

(defn load
  "從 path 讀回一份記憶；檔案不存在、不是 JSON、形狀不對都丟中文錯誤。"
  [path]
  (def [ok raw] (protect (slurp path)))
  (unless ok (error (string "讀不到對話檔：" path)))
  (def [ok2 data] (protect (json/decode (string raw) true)))
  (unless ok2 (error (string "對話檔不是合法 JSON：" path)))
  (from-data data))
