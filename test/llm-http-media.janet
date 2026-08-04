# llm-http：圖像輸入（media）與 tool 宣告（tool-spec）。純函式，不打網路。

(import ../modules/llm-http/init :as llm)

# ── 圖像輸入（vision）─────────────────────────────────────────────
(assert (= "image/png"  (llm/mime-for-path "/tmp/a.PNG")))
(assert (= "image/jpeg" (llm/mime-for-path "/tmp/a.jpg")))
(assert (= "image/webp" (llm/mime-for-path "/tmp/a.webp")))

# 沒給圖 → content 還是字串（最常用的路徑保持乾淨）
(def m-plain (llm/user-message "嗨"))
(assert (= "嗨" (m-plain :content)) "純文字時 content 是字串")

# 有給圖 → content 變 parts 陣列，文字在前、圖在後
(def m-img (llm/user-message "這是什麼" ["https://example.com/a.png"]))
(assert (indexed? (m-img :content)) "帶圖時 content 是陣列")
(assert (= "text" (get-in m-img [:content 0 :type])))
(assert (= "image_url" (get-in m-img [:content 1 :type])))
(assert (= "https://example.com/a.png" (get-in m-img [:content 1 :image_url :url])))

# 本機檔案 → data URI（拿本測試檔自己當 bytes 來源，不必另外造檔）
(def uri (llm/data-uri (dyn :current-file) "image/png"))
(assert (string/has-prefix? "data:image/png;base64," uri) "data URI 前綴")

# ── tool 宣告 ───────────────────────────────────────────────────────
(def spec (llm/tool-spec "echo" "回聲" {:type "object" :properties {}}))
(assert (= "function" (spec :type)))
(assert (= "echo" (get-in spec [:function :name])))
(assert (= 2 (length llm/demo-tools)) "示範工具有兩個")

(print "llm-http media／tool-spec 測試通過 ✓")
