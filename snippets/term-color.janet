#!/usr/bin/env janet
# 終端機上色與進度條——而且**被導向管線時自動關掉**。
# 跑法：
#   janet snippets/term-color.janet          ← 有色、有進度條
#   janet snippets/term-color.janet | cat    ← 自動變純文字，下游不會吃到亂碼
#
# 為什麼要這支：直接印 ANSI 逃脫碼的話，只要有人 `> log.txt` 或 `| grep`，
# 檔案裡就全是 \e[31m 這種垃圾。判斷式只有一行：(os/isatty stdout)。
# 相關：docs/39（os/isatty）、docs/41（rawterm/size 的坑）。

(import spork/rawterm)

# ── 是不是接到人 ──────────────────────────────────────────────
(def 上色? (os/isatty stdout))

(def 碼 {:紅 "31" :綠 "32" :黃 "33" :藍 "34" :洋紅 "35" :青 "36"
         :粗 "1" :淡 "2" :底線 "4"})

(defn 色
  "把 s 包上 ANSI 樣式；沒接終端機就原樣回傳。"
  [s & 樣式]
  (if-not 上色?
    (string s)
    (string "\e[" (string/join (map |(get 碼 $ "0") 樣式) ";") "m" s "\e[0m")))

# ── 終端機寬度（安全版）────────────────────────────────────────
(defn 終端寬度 []
  ``回終端機的行數。
  ⚠ rawterm/size 在非終端機下回的是未初始化的記憶體（不是 nil、不報錯），
  所以先問 isatty，再把 0 當成「不知道」。``
  (if-not (os/isatty stdout)
    80
    (let [[_ 行] (rawterm/size)] (if (pos? 行) 行 80))))

# ── 進度條 ────────────────────────────────────────────────────
(defn 進度條
  "畫一條進度條。接管線時改印純文字的百分比，不用 \\r。"
  [做了 總共 &opt 標籤]
  (default 標籤 "")
  (def 比例 (if (zero? 總共) 1 (/ 做了 總共)))
  (def 百分比 (math/round (* 100 比例)))
  (if-not 上色?
    # ⚠ Janet 的 printf 自己會換行（不換行的是 prinf）——管線模式一行一筆，好 grep
    (printf "%s %d%%" 標籤 百分比)
    (do
      (def 可用 (max 10 (- (終端寬度) (rawterm/monowidth 標籤) 12)))
      (def 滿 (math/floor (* 可用 比例)))
      (prin "\r" 標籤 " ["
            (色 (string/repeat "█" 滿) :綠)
            (string/repeat "░" (- 可用 滿))
            (string/format "] %3d%%" 百分比))
      (:flush stdout))))

(defn main [&]
  # ⚠ 這裡刻意不用 %-6s——它數的是 byte，中文標籤會歪（見 aligned-table.janet）
  (defn 靠左 [s w]
    (string s (string/repeat " " (max 0 (- w (rawterm/monowidth (string s)))))))

  (print (色 "== 樣式 ==" :粗))
  (each s [:紅 :綠 :黃 :藍 :洋紅 :青]
    (printf "  %s %s" (靠左 s 6) (色 "範例文字 sample" s)))
  (printf "  %s %s" (靠左 "組合" 6) (色 "粗體 + 底線 + 紅" :粗 :底線 :紅))

  (printf "\n接到終端機嗎：%j（stderr：%j）" 上色? (os/isatty stderr))
  (printf "終端寬度（安全讀法）：%d" (終端寬度))

  (print (色 "\n== 進度條 ==" :粗))
  (for i 0 21
    (進度條 i 20 "下載中")
    (ev/sleep 0.02))
  (when 上色? (print))
  (print (色 "完成 ✓" :綠 :粗))

  (print "\n把這支用 | cat 再跑一次，上面全部會變成純文字。"))
