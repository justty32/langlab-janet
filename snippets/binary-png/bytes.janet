# 位元組層的通用工具 —— 跟 PNG 無關，處理任何二進位格式都用得上。
#
# 重點：
#   * buffer/string 用 (in b i) 取第 i 個位元組（是數字 0-255）
#   * ★ 檔案格式多半是「大端序」(big-endian)，x86 是小端序，不能直接 ffi/read

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
