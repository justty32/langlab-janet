# 圖像輸入（vision input）—— 把本機圖檔轉成 OpenAI 相容的 content part。
#
# ★ 只做「輸入」：讀圖檔 → base64 → data URI → 塞進 messages。
#   不做音訊、不做圖像生成、不碰 modalities。
#
# 關鍵在 messages 裡那則 user 訊息的 content 形狀：
#   純文字 → content 直接是字串（最常用的路徑，維持簡單，別為了統一改成陣列）
#   帶圖   → content 換成 parts 陣列：
#     [@{:type "text"      :text "描述這張圖"}
#      @{:type "image_url" :image_url @{:url "data:image/png;base64,…"}}]
#
# ⚠ 不是每個模型都吃圖：DeepSeek 現行的純文字模型就不行，送過去的行為從報錯到
#   **靜默無視**都有可能。挑 endpoint 前先看 endpoints/specs 的 :vision? 欄位。

(import spork/base64)

(def mime-by-ext
  "副檔名 → mime type。OpenAI 相容端點目前實務上就吃這四種。"
  {".png"  "image/png"
   ".jpg"  "image/jpeg"
   ".jpeg" "image/jpeg"
   ".gif"  "image/gif"
   ".webp" "image/webp"})

(defn mime-for-path
  "依副檔名猜 mime type；認不出來就當 image/png（多數端點靠 magic bytes 自己認）。"
  [path]
  (def lower (string/ascii-lower path))
  (var found nil)
  (eachp [ext mime] mime-by-ext
    (when (and (nil? found) (string/has-suffix? ext lower))
      (set found mime)))
  (or found "image/png"))

(defn data-uri
  ``把本機圖檔讀成 data URI 字串：data:<mime>;base64,<...>。

  ⚠ 圖是整份塞進 JSON body 的，base64 會膨脹約 4/3；幾 MB 的圖打過去會很慢，
  真的要大圖請自己先縮。``
  [path &opt mime]
  # slurp 讀不到檔會自己丟例外，不另外包裝；它是以 :rb 開檔，二進位安全。
  # ★ 回來的是 **buffer**，base64/encode 只吃 string，要先 (string …) 包一層。
  (def bytes (string (slurp path)))
  (string "data:" (or mime (mime-for-path path)) ";base64," (base64/encode bytes)))

(defn text-part
  "組一個文字 part。"
  [text]
  @{:type "text" :text text})

(defn image-part
  "組一個圖像 part。來源可以是本機路徑，也可以直接給 http(s):// 或 data: 開頭的 URL。"
  [src]
  (def url
    (if (or (string/has-prefix? "http" src) (string/has-prefix? "data:" src))
      src
      (data-uri src)))
  @{:type "image_url" :image_url @{:url url}})

(defn user-message
  ``組一則 role="user" 的訊息。

  沒給圖 → content 就是原本那個字串（最常用的路徑保持乾淨）。
  有給圖 → content 變成 parts 陣列，文字在前、圖依序在後。

  images 是路徑／URL 的陣列，可以多張。``
  [text &opt images]
  (if (or (nil? images) (empty? images))
    @{:role "user" :content text}
    (do
      (def parts @[])
      (when (and text (not (empty? text))) (array/push parts (text-part text)))
      (each src images (array/push parts (image-part src)))
      @{:role "user" :content parts})))
