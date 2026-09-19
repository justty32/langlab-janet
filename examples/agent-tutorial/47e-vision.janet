# 47 ⑤ —— 圖像輸入：content 從「一個字串」變成「一個 parts 陣列」。
#
# 圖不是另外開一個欄位，而是把 user 訊息的 content 換形狀：
#   純文字 → "描述這張圖"
#   帶圖   → [{:type "text" :text "…"} {:type "image_url" :image_url {:url "data:…"}}]
#
# 離線可跑：janet examples/agent-tutorial/47e-vision.janet
# 教學：docs/47e-圖像輸入.md

(import spork/base64)
(import ../../modules/llm-http/init :as llm)
(import ./fake-server :as fs)

(defn 分隔 [t] (print "\n── " t " " (string/repeat "─" (max 2 (- 50 (length t))))))

# 16×16 純紅色 PNG（79 bytes），寫死在這裡免得範例還要準備素材。
(def 紅色小圖
  "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAAFklEQVR42mP47+BAEmIY1TCqYfhqAABcdX8QBIxpfgAAAABJRU5ErkJggg==")

# 假後端：把它「看到什麼」講出來，好證明圖真的送到了 wire 上。
(defn 回應 [payload _n]
  (def c (get-in payload [:messages 0 :content]))
  [200 (fs/text-reply
         (if (indexed? c)
           (string "(fake) I got " (length c) " parts: "
                   (string/join (map |(get $ :type) c) ", "))
           (string "(fake) I got plain text: " c)))])

(defn 摘要 [part]
  (if (= "text" (get part :type))
    (string "text      " (get part :text))
    (let [u (get-in part [:image_url :url])]
      (string "image_url " (string/slice u 0 (min 44 (length u)))
              "…（共 " (length u) " 字元）"))))

(defn main [&]
  (def 圖檔 (string (or (os/getenv "TMPDIR") "/tmp") "/janet-47e-red.png"))
  (spit 圖檔 (base64/decode 紅色小圖))          # base64/decode 回 buffer，spit 吃得下

  (def 假 (fs/start :port 45826 :reply 回應))
  (defer (do (fs/stop 假) (os/rm 圖檔))
    (def cfg (llm/endpoint {:model "fake-model" :url (假 :url)
                            :api-key "sk-fake" :vision? true}))

    (分隔 "① 沒給圖：content 就是一個字串")
    (pp (llm/user-message "What colour is it?"))

    (分隔 "② 給了圖：content 變成 parts 陣列")
    (def msg (llm/user-message "What colour is it?" [圖檔]))
    (each p (msg :content) (print "  " (摘要 p)))

    (分隔 "③ data URI 長什麼樣")
    (def uri (llm/data-uri 圖檔))
    (printf "前綴   = %s" (first (string/split "," uri)))
    (printf "mime   = %s（副檔名猜的，認不出來就當 image/png）" (llm/mime-for-path 圖檔))
    (printf "原檔   = %d bytes" (length (slurp 圖檔)))
    (printf "編完後 = %d 字元   ← base64 膨脹約 4/3，整份塞進 JSON body 送出去"
            (length uri))

    (分隔 "④ 真的送出去")
    (print (llm/ask cfg "What colour is it?" nil [圖檔]))
    (printf "後端收到的 content 形狀：%s"
            (if (indexed? (get-in 假 [:log 0 :messages 0 :content])) "陣列" "字串"))

    (分隔 "⑤ 圖也可以直接給網址")
    # 開頭是 http 或 data: 就原樣用，不會去讀本機檔案
    (pp (llm/image-part "https://example.com/a.png"))

    (分隔 "⑥ ⚠ 不是每個模型都吃圖")
    (print "  endpoint 的 :vision? 欄位就是拿來標這件事的：")
    (printf "  這份 cfg :vision? = %q" (cfg :vision?))
    (print "  送圖給純文字模型（例如 DeepSeek 現行的），行為從報錯到靜默無視都有；")
    (print "  靜默無視最難查——你會拿到 exit 0 加一段看起來像答案的東西。")))
