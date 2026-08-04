#!/usr/bin/env janet
# 處理純二進位資料：以 PNG 為例，讀檔、驗魔數、走訪 chunk、解出寬高、驗 CRC。
# 跑法：
#   janet snippets/binary-png/main.janet                    # 用內建的 1x1 測試圖
#   janet snippets/binary-png/main.janet /path/to/some.png  # 讀真的檔案
#
# 重點：
#   * (slurp path) 讀二進位完全沒問題——它本來就回 buffer，不會動內容
#   * ★ 檔案格式多半是大端序，別直接用 ffi/read（它照「機器」的位元組序）
#   * 位元組層的通用工具在 bytes.janet，PNG 格式本身在 png.janet

(import spork/base64)
(import ./bytes :as by)
(import ./png)

(defn h [s] (printf "\n── %s" s))

(defn main [& args]
  (def path (get args 1))
  (def data (if path
              (slurp path)                     # ★ slurp 讀二進位不會壞
              (buffer (base64/decode png/測試圖-b64))))

  (h "讀進來的東西")
  (printf "  來源      %s" (or path "內建的 1x1 測試圖（base64 解出來）"))
  (printf "  型別      %q  ← slurp 回的是 buffer，不是 string" (type data))
  (printf "  大小      %d bytes" (length data))
  (printf "  前 8 byte %q" (map |(in data $) (range 8)))

  (h "hex dump（除錯二進位的第一招）")
  (by/hex-dump data 48)

  (h "驗魔數")
  (printf "  是 PNG 嗎？%q" (png/png? data))
  (unless (png/png? data)
    (print "  不是 PNG，後面就不解了。")
    (os/exit 0))

  (h "大端序 vs 小端序")
  (printf "  IHDR 長度欄的 4 個 byte：%q" (map |(in data (+ 8 $)) (range 4)))
  (printf "  當大端序讀 (u32-be) => %d  ✓ PNG 用這個" (by/u32-be data 8))
  (printf "  當小端序讀 (u32-le) => %d  ✗ 差很多" (by/u32-le data 8))
  (printf "  ffi/read 是按「機器」的序（x86 = 小端）=> %q"
          (ffi/read :u32 (slice data 8 12)))
  (print "  ★ 所以解檔案格式別直接用 ffi/read，除非你確定序一致")

  (h "走訪 chunk")
  (def cs (png/chunks data))
  (each c cs
    (printf "  %-5s 長度 %-6d CRC %08X  %s"
            (c :type) (c :length) (c :crc)
            (if (c :crc-ok) "✓ 相符" "✗ 不符")))
  (printf "  共 %d 個 chunk，全部 CRC 正確？%q"
          (length cs) (all |($ :crc-ok) cs))

  (h "解 IHDR")
  (def info (png/ihdr data (first cs)))
  (printf "  尺寸       %d x %d" (info :width) (info :height))
  (printf "  位元深度   %d" (info :bit-depth))
  (printf "  色彩型別   %d（%s）" (info :color-type) (info :color-name))
  (printf "  交錯       %s" (if (zero? (info :interlace)) "無" "Adam7"))

  (h "二進位的其他常用招")
  (printf "  切一段        %q" (slice data 0 4))
  # ★ base64/encode 只吃 string，buffer 要先包一層
  (printf "  轉 base64     %s…" (slice (base64/encode (string data)) 0 24))
  (printf "  CRC32 全檔    %08X" (png/crc32 data))
  (printf "  找某個 byte   IDAT 在位移 %q" (string/find "IDAT" data))
  (printf "  自己組位元組  %q" (string/from-bytes 0x89 0x50 0x4E 0x47))
  (print "  寫回檔案      (spit \"out.png\" data)   ← buffer 直接寫，不用轉")
  (print))
