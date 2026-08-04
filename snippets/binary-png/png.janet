# PNG 格式本身 —— 魔數、chunk 走訪、CRC 驗證、IHDR 解讀。
#
# PNG 的結構：8 byte 魔數，接著一連串 chunk，
# 每個 chunk = 長度(4) + 型別(4) + 資料(長度) + CRC(4)，全部大端序。

(import spork/crc)
(import ./bytes :as by)

(def PNG-MAGIC @[137 80 78 71 13 10 26 10])   # \x89 P N G \r \n \x1a \n

(def crc32 (crc/make-variant 32 0x04C11DB7 0xFFFFFFFF true 0xFFFFFFFF))

(defn png? [b]
  (and (>= (length b) 8)
       (all |(= (in b $) (in PNG-MAGIC $)) (range 8))))

(defn chunks
  "走訪 PNG 的 chunk。回傳 @[@{:type :length :data-offset :crc :crc-ok} …]"
  [b]
  (def out @[])
  (var off 8)                                   # 跳過魔數
  (while (< (+ off 8) (length b))
    (def len (by/u32-be b off))
    (def ctype (string (slice b (+ off 4) (+ off 8))))
    (def data-off (+ off 8))
    (def crc-off (+ data-off len))
    (when (> (+ crc-off 4) (length b)) (break))
    (def stored-crc (by/u32-be b crc-off))
    # ★ PNG 的 CRC 涵蓋「型別 + 資料」，不含長度欄
    (def calc-crc (crc32 (slice b (+ off 4) crc-off)))
    (array/push out @{:type ctype
                      :length len
                      :data-offset data-off
                      :crc stored-crc
                      :crc-ok (= stored-crc calc-crc)})
    (set off (+ crc-off 4)))
  out)

(def color-types
  {0 "灰階" 2 "RGB" 3 "調色盤" 4 "灰階+Alpha" 6 "RGBA"})

(defn ihdr
  "IHDR 一定是第一個 chunk，13 bytes：寬(4) 高(4) 位元深度(1) 色彩型別(1)
  壓縮(1) 濾波(1) 交錯(1)。"
  [b c]
  (def o (c :data-offset))
  @{:width       (by/u32-be b o)
    :height      (by/u32-be b (+ o 4))
    :bit-depth   (in b (+ o 8))
    :color-type  (in b (+ o 9))
    :color-name  (get color-types (in b (+ o 9)) "?")
    :compression (in b (+ o 10))
    :filter      (in b (+ o 11))
    :interlace   (in b (+ o 12))})

# 內建一張 1x1 的 PNG（base64），這樣不依賴外部檔案也能跑
(def 測試圖-b64
  (string "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4"
          "2mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg=="))
