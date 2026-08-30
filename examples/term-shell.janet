# 配合 docs/41-spork-終端與-shell.md
#
#   janet examples/term-shell.janet
#   janet examples/term-shell.janet | cat    ← 再跑一次，看 rawterm/size 的差別
#
# ⚠ 不碰 rawterm/begin（raw mode）與 getline——那兩個是互動的，
#   寫進自動測試會卡住或把終端機弄壞。

(import spork/sh-dsl :as sh)
(import spork/rawterm)

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-34s => %j" 說明 結果))

(節 "sh-dsl 的四個形式")
(print "  ($ echo hi) 的輸出直接印出去 ↓")
(秀 "($ echo hi)      回 exit code" (sh/$ echo hi))
(秀 "($< echo hi)     回 stdout" (sh/$< echo hi))
(秀 "($<_ echo hi)    去掉尾換行" (sh/$<_ echo hi))
(秀 "($? true)" (sh/$? true))
(秀 "($? false)" (sh/$? false))

(節 "⚠ | 在這幾個巨集裡真的是管線")
(秀 "($<_ printf \"b\\na\\n\" | sort)" (sh/$<_ printf "b\na\n" | sort))
(print "  平常 | 是短函式（|(+ $ 1)）——只有在這幾個巨集的參數位置才被當成管線")

(節 "⚠ $< 回的是 buffer，不是 string")
(秀 "(type ($< echo hi))" (type (sh/$< echo hi)))
(秀 "(= \"hi\" ($<_ echo hi))  ← buffer ≠ string" (= "hi" (sh/$<_ echo hi)))
(秀 "(string ($<_ echo hi))   ← 要先轉" (string (sh/$<_ echo hi)))

(節 "失敗要不要拋錯：*errexit*")
(秀 "預設 ($ false)  不拋，回 exit code" (sh/$ false))
(printf "  %-34s => %s" "with-dyns 開 errexit"
        (try (with-dyns [sh/*errexit* true] (sh/$ false))
             ([e] (string "拋了：" e))))
(print "  *errexit* 與 *pipefail* 是 defdyn 定義的動態變數（見 docs/40）")

(節 "三種跑外部命令的方式，回的東西不一樣")
(printf "  %-22s => %j" "os/execute [\"false\"] :p" (os/execute ["false"] :p))
(if (= :windows (os/which))
  (print "  os/shell 的 wait status 編碼是 POSIX 專屬的，Windows 上跳過")
  (printf "  %-22s => %j   ⚠ exit code × 256（見 docs/39）" "(os/shell \"false\")" (os/shell "false")))
(printf "  %-22s => %j" "(sh/$ false)" (sh/$ false))

(節 "★ rawterm/monowidth：中文表格終於對得齊")
(each s ["abc" "中文" "中文abc" "日本語です"]
  (printf "  %-14s length(byte)=%-4j monowidth(顯示寬)=%j" s (length s) (rawterm/monowidth s)))
(print "  ↑ byte 數 ≠ 字元數 ≠ 顯示寬度，三個都不一樣")

(print "\n  用 %-10s 排版（printf 數的是 byte，所以歪）：")
(each s ["abc" "中文" "中文abc"] (printf "    |%-10s|" s))

(defn pad [s w]
  (string s (string/repeat " " (max 0 (- w (rawterm/monowidth s))))))
(print "\n  用 monowidth 自己補（對齊）：")
(each s ["abc" "中文" "中文abc"] (printf "    |%s|" (pad s 10)))
(print "  ↑ 這就是 docs/28b 說「要漂亮的中文表格得自己算寬度」缺的那塊")

(節 "slice-monowidth：按顯示寬度切，不會把中文切一半")
(printf "  %-34s => %s" "(slice-monowidth \"中文abc\" 5)"
        (string (rawterm/slice-monowidth "中文abc" 5)))
(print "  中文佔 4 格 + a 佔 1 格 = 5")

(節 "⚠ rawterm/size 在非終端機下回的是垃圾")
(秀 "(rawterm/isatty)" (rawterm/isatty))
(秀 "(rawterm/size)" (rawterm/size))
(if (rawterm/isatty)
  (print "  現在接的是終端機，上面應該是合理的 (列 行)")
  (print "  ↑ 現在輸出被導走了，上面那組數字是**未初始化的記憶體**，每次跑都不同"))
(print "  它不報錯、也不回 nil。安全的讀法：")
(def [列 行] (if (rawterm/isatty) (rawterm/size) [24 80]))
(def 實際行 (if (pos? 行) 行 80))
(秀 "先問 isatty，再把 0 當成未知" [列 實際行])

(print "\n✓ term-shell 跑完")
