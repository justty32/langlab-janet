# llm-http 範例 ⑤ —— 圖像輸入（vision input）。
#
# 關鍵只在 messages 裡那則 user 訊息的 content 形狀：
#   純文字 → content 直接是字串
#   帶圖   → content 換成 parts 陣列：
#     [@{:type "text"      :text "描述這張圖"}
#      @{:type "image_url" :image_url @{:url "data:image/png;base64,…"}}]
#
# media/user-message 幫你組好；ask 的第三個參數收的就是圖檔路徑／URL 陣列。
#
# ⚠ **不是每個模型都吃圖**：送圖給純文字模型（例如 DeepSeek），行為從報錯到
#   **靜默無視**都有可能。挑 endpoint 前先看它的 :vision? 欄位。
# ⚠ 圖是整份塞進 JSON body 的，base64 會膨脹約 4/3。幾 MB 的圖打過去會很慢，
#   真的要大圖請自己先縮。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   * OpenAI 相容伺服器在跑（預設 litellm proxy http://127.0.0.1:4000）
#   * 後面接的模型要**吃圖**（`local` 這條指到 LM Studio 的 gemma-4 系列，可以）
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/05-vision.janet                    # 用內建的紅色小圖
#   janet examples/llm-http/05-vision.janet 我的照片.png        # 用自己的圖
#   janet examples/llm-http/05-vision.janet a.png b.png        # 一次送多張

(import spork/base64)
(import ../../modules/llm-http/init :as llm)

(def hint "\n提示：後端沒起來。先起 litellm proxy（見 01-minimal.janet 檔頭），位址用 127.0.0.1。")

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)                       # ★ 先把 stdout 吐出來，錯誤才不會插隊到前面
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

# 16×16 純紅色 PNG（79 bytes），寫死在這裡免得 example 還要準備素材。
(def red-png-base64
  "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR42mP47+BAEmIY1TCqYfhqAABcdX8QBIxpfgAAAABJRU5ErkJggg==")

(defn make-sample-image
  "把內建的紅色小圖寫成暫存檔，回傳路徑。"
  []
  (def path (string (or (os/getenv "TMPDIR") "/tmp") "/llm-http-example-red.png"))
  # ★ base64/decode 回來的是 buffer，spit 吃得下
  (spit path (base64/decode red-png-base64))
  path)

(defn main [& args]
  (def cfg (llm/endpoint "local"))
  (def user-images (slice args 1))
  (def images (if (empty? user-images) @[(make-sample-image)] (array ;user-images)))

  # ⚠ 先看這條線吃不吃圖；:vision? 是 false 就先警告（nil ＝ 沒表態，不吵）
  (when (false? (cfg :vision?))
    (eprintf "⚠ endpoint %s 目前指到的模型不吃圖，送過去可能報錯、也可能被靜默無視。"
             (cfg :name)))

  (printf "要送的圖：%s" (string/join images "、"))

  # ── ① 先看 media 這一層做了什麼（不連線也看得到）──────────────────
  (print "\n── content parts 長這樣 ──")
  (def msg (llm/user-message "這張圖主要是什麼顏色？" images))
  (each part (msg :content)
    (case (part :type)
      "text"      (printf "  text      %s" (part :text))
      "image_url" (let [u (get-in part [:image_url :url])]
                    (printf "  image_url %s…（共 %d 字元）"
                            (string/slice u 0 (min 48 (length u))) (length u)))))

  # 副檔名 → mime type 是猜的，認不出來就當 image/png
  (printf "\n（mime 判斷：%s → %s）" (first images) (llm/mime-for-path (first images)))

  # ── ② 真的送出去 ──────────────────────────────────────────────────
  # ask 的第三個參數就是圖；不要 system 的話中間給 nil。
  (print "\n── 送出去問 ──")
  (when-let [a (attempt "圖像問答"
                        |(llm/ask cfg "這張圖主要是什麼顏色？用兩個字回答。" nil images))]
    (print "答 = " a))

  # ── ③ 圖也可以直接給網址，不必是本機檔案 ──────────────────────────
  (print "\n★ image-part 也吃 http(s):// 與 data: 開頭的字串，那時就不會去讀本機檔案：")
  (pp (llm/image-part "https://example.com/a.png")))
