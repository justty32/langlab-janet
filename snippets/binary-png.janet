#!/usr/bin/env janet
# 處理純二進位資料：以 PNG 為例，讀檔、驗魔數、走訪 chunk、解出寬高、驗 CRC。
# 跑法：
#   janet snippets/binary-png.janet                    # 用內建的 1x1 測試圖
#   janet snippets/binary-png.janet /path/to/some.png  # 讀真的檔案
#
# 重點：
#   * (slurp path) 讀二進位完全沒問題——它本來就回 buffer，不會動內容
#   * buffer/string 用 (in b i) 取第 i 個位元組（是數字 0-255）
#   * ★ 檔案格式多半是「大端序」(big-endian)，x86 是小端序，不能直接 ffi/read
#   * 想按結構解，(ffi/read (ffi/struct …) buf) 很方便——但它照「機器」的位元組序

(import spork/base64)
(import spork/crc)

(defn h [s] (printf "\n── %s" s))

# ── 位元組層工具 ─────────────────────────────────────────────────────
(defn u32-be
  "從 offset 讀 4 個位元組，當大端序無號整數。PNG／多數網路格式都是這個。"
  [b offset]
  (+ (* (in b offset)       0x1000000)
     (* (in b (+ offset 1)) 0x10000)
     (* (in b (+ offset 2)) 0x100)
     (in b (+ offset 3))))

(defn u32-le
  "小端序版本，對照用。"
  [b offset]
  (+ (in b offset)
     (* (in b (+ offset 1)) 0x100)
     (* (in b (+ offset 2)) 0x10000)
     (* (in b (+ offset 3)) 0x1000000)))

(defn hex-dump
  "印出 n 個位元組的 hex + ASCII，除錯二進位時最常用的東西。"
  [b &opt n start]
  (default n 64)
  (default start 0)
  (def end (min (length b) (+ start n)))
  (var i start)
  (while (< i end)
    (def row-end (min end (+ i 16)))
    (def bytes (seq [j :range [i row-end]] (in b j)))
    (printf "  %08X  %-48s |%s|"
            i
            (string/join (map |(string/format "%02X" $) bytes) " ")
            (string/from-bytes
              ;(map |(if (and (>= $ 32) (< $ 127)) $ (chr ".")) bytes)))
    (+= i 16)))

# ── PNG 專用 ─────────────────────────────────────────────────────────
(def PNG-MAGIC @[137 80 78 71 13 10 26 10])   # \x89 P N G \r \n \x1a \n

(def crc32 (crc/make-variant 32 0x04C11DB7 0xFFFFFFFF true 0xFFFFFFFF))

(defn png? [b]
  (and (>= (length b) 8)
       (all |(= (in b $) (in PNG-MAGIC $)) (range 8))))

(defn chunks
  "走訪 PNG 的 chunk：每個是 長度(4) + 型別(4) + 資料(長度) + CRC(4)。
  回傳 @[@{:type :length :data-offset :crc :crc-ok} …]"
  [b]
  (def out @[])
  (var off 8)                                   # 跳過魔數
  (while (< (+ off 8) (length b))
    (def len (u32-be b off))
    (def ctype (string (slice b (+ off 4) (+ off 8))))
    (def data-off (+ off 8))
    (def crc-off (+ data-off len))
    (when (> (+ crc-off 4) (length b)) (break))
    (def stored-crc (u32-be b crc-off))
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
  @{:width       (u32-be b o)
    :height      (u32-be b (+ o 4))
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

(defn main [& args]
  (def path (get args 1))
  (def data (if path
              (slurp path)                     # ★ slurp 讀二進位不會壞
              (buffer (base64/decode 測試圖-b64))))

  (h "讀進來的東西")
  (printf "  來源      %s" (or path "內建的 1x1 測試圖（base64 解出來）"))
  (printf "  型別      %q  ← slurp 回的是 buffer，不是 string" (type data))
  (printf "  大小      %d bytes" (length data))
  (printf "  前 8 byte %q" (map |(in data $) (range 8)))

  (h "hex dump（除錯二進位的第一招）")
  (hex-dump data 48)

  (h "驗魔數")
  (printf "  是 PNG 嗎？%q" (png? data))
  (unless (png? data)
    (print "  不是 PNG，後面就不解了。")
    (os/exit 0))

  (h "大端序 vs 小端序")
  (printf "  IHDR 長度欄的 4 個 byte：%q" (map |(in data (+ 8 $)) (range 4)))
  (printf "  當大端序讀 (u32-be) => %d  ✓ PNG 用這個" (u32-be data 8))
  (printf "  當小端序讀 (u32-le) => %d  ✗ 差很多" (u32-le data 8))
  (printf "  ffi/read 是按「機器」的序（x86 = 小端）=> %q"
          (ffi/read :u32 (slice data 8 12)))
  (print "  ★ 所以解檔案格式別直接用 ffi/read，除非你確定序一致")

  (h "走訪 chunk")
  (def cs (chunks data))
  (each c cs
    (printf "  %-5s 長度 %-6d CRC %08X  %s"
            (c :type) (c :length) (c :crc)
            (if (c :crc-ok) "✓ 相符" "✗ 不符")))
  (printf "  共 %d 個 chunk，全部 CRC 正確？%q"
          (length cs) (all |($ :crc-ok) cs))

  (h "解 IHDR")
  (def info (ihdr data (first cs)))
  (printf "  尺寸       %d x %d" (info :width) (info :height))
  (printf "  位元深度   %d" (info :bit-depth))
  (printf "  色彩型別   %d（%s）" (info :color-type) (info :color-name))
  (printf "  交錯       %s" (if (zero? (info :interlace)) "無" "Adam7"))

  (h "二進位的其他常用招")
  (printf "  切一段        %q" (slice data 0 4))
  # ★ base64/encode 只吃 string，buffer 要先包一層
  (printf "  轉 base64     %s…" (slice (base64/encode (string data)) 0 24))
  (printf "  CRC32 全檔    %08X" (crc32 data))
  (printf "  找某個 byte   IDAT 在位移 %q" (string/find "IDAT" data))
  (printf "  自己組位元組  %q" (string/from-bytes 0x89 0x50 0x4E 0x47))
  (print "  寫回檔案      (spit \"out.png\" data)   ← buffer 直接寫，不用轉")
  (print))
