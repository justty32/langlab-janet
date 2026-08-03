#!/usr/bin/env janet
# 基礎檔案 IO：整檔讀寫、逐行、附加、二進位、暫存檔、原子寫入。
# 跑法：janet snippets/file-io.janet
#
# 一句話結論：
#   * 九成情況用 (slurp path) 和 (spit path data) 就夠了——整檔進出，一行搞定
#   * 檔案很大、要逐行處理、或要邊寫邊 flush，才需要 file/open
#   * file/open 開出來的東西一定要關；用 (with [f (file/open …)] …) 讓它自動關

(def tmp (string (or (os/getenv "TMPDIR") "/tmp") "/janet-lab-io"))
(os/mkdir tmp)
(def p (string tmp "/demo.txt"))

(defn h [s] (printf "\n── %s" s))

(defn main [&]
  # ── 1) 最常用：整檔進 / 整檔出 ─────────────────────────────────
  (h "slurp / spit")
  (spit p "第一行\n第二行\n第三行\n")
  (def 內容 (slurp p))
  # ★ slurp 回來的是 buffer 不是 string。多數場合可以直接用（都是 bytes），
  #   但要當 table 的 key、或要比較相等，記得先 (string 內容)
  (printf "  slurp 回來 %d bytes，型別 %q（不是 :string！）" (length 內容) (type 內容))
  (prin 內容)
  (spit p "追加的一行\n" :a)                 # 第三參數 :a = append
  (printf "  append 之後共 %d 行"
          (length (string/split "\n" (string/trimr (slurp p)))))

  # ── 2) 讀成一行一行 ────────────────────────────────────────────
  (h "切成行")
  (def lines (string/split "\n" (string/trimr (slurp p))))
  (each [i l] (pairs lines) (printf "  [%d] %s" i l))
  (print "  ★ 記得 string/trimr，否則結尾的 \\n 會多切出一個空字串")

  # ── 3) 大檔：不要整個讀進來，用 file/lines 串流 ──────────────────
  (h "file/lines：逐行串流，記憶體只吃一行")
  (with [f (file/open p :r)]                 # with 會自動 close，就算中途出錯
    (var n 0)
    (each line (file/lines f)
      (++ n)
      (printf "  第 %d 行長度 %d" n (length (string/trimr line))))
    (printf "  共 %d 行" n))

  # ── 4) file/open 的模式與逐塊讀 ─────────────────────────────────
  (h "file/open 模式")
  (print "  :r 讀  :w 寫（清空）  :a 附加  加 b = 二進位  加 + = 讀寫")
  (with [f (file/open p :r)]
    (printf "  讀 6 bytes  => %s" (file/read f 6))
    (printf "  讀一行      => %s" (string/trimr (string (file/read f :line))))
    (printf "  現在位置    => %d" (file/tell f))
    (file/seek f :set 0)                     # :set 開頭 :cur 目前 :end 結尾
    (printf "  seek 回 0 再讀全部 %d bytes" (length (file/read f :all))))

  # ── 5) 寫：要即時看到就 flush ───────────────────────────────────
  (h "寫檔 / flush")
  (with [f (file/open p :w)]
    (file/write f "a=1\n" "b=2\n")           # 可以一次給多段
    (file/flush f)                            # 不 flush 的話會留在緩衝區
    (printf "  寫完當下檔案大小 = %d" (os/stat p :size)))

  # ── 6) 二進位 ──────────────────────────────────────────────────
  (h "二進位")
  (def bin (string tmp "/demo.bin"))
  (with [f (file/open bin :wb)]
    (file/write f (string/from-bytes 0 1 2 255)))
  (def raw (slurp bin))                      # slurp 也讀得了二進位
  (printf "  寫了 %d bytes => %q" (length raw) (buffer raw))
  (printf "  第 3 個 byte = %d" (in raw 3))

  # ── 7) 存在嗎 / 安全讀 ─────────────────────────────────────────
  (h "先確認再讀")
  (defn slurp-or [path dflt]
    (if (os/stat path :mode) (slurp path) dflt))
  (printf "  存在的     => %d bytes" (length (slurp-or p "")))
  (printf "  不存在的   => %q" (slurp-or "/no/such/file" :預設值))
  (def [ok err] (protect (slurp "/no/such/file")))
  (printf "  硬讀不存在的 => ok=%q err=%s" ok err)

  # ── 8) 暫存檔 ──────────────────────────────────────────────────
  (h "file/temp：用完自動消失的暫存檔")
  (def t (file/temp))
  (file/write t "暫時的東西")
  (file/seek t :set 0)
  (printf "  讀回 => %s" (file/read t :all))
  (file/close t)                             # 關掉就沒了，不留在磁碟上

  # ── 9) 原子寫入：先寫暫存再 rename ─────────────────────────────
  (h "原子寫入（避免寫到一半被中斷、檔案半殘）")
  (defn spit-atomic [path data]
    (def tmp-path (string path ".tmp"))
    (spit tmp-path data)
    (os/rename tmp-path path))               # rename 在同一個檔案系統上是原子的
  (spit-atomic p "整份換掉\n")
  (printf "  => %s" (string/trimr (string (slurp p))))

  # ── 10) 收尾 ───────────────────────────────────────────────────
  (h "收尾")
  (each f [p bin] (when (os/stat f :mode) (os/rm f)))
  (os/rmdir tmp)
  (print "  暫存檔已清掉\n"))
