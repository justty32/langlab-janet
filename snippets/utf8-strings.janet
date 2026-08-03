#!/usr/bin/env janet
# UTF-8 字串處理：長度、切片、切割、反轉、逐字走訪。
# 跑法：janet snippets/utf8-strings.janet ["自己的字串"]
#
# 先講最重要的一件事：
#   ★ Janet 的字串是「位元組序列」，不是「字元序列」。
#     (length "漢字") => 6 不是 2；("漢" 0) => 230 是那個字的第一個位元組。
#   所以凡是「按字數」做的事都要自己處理，核心不會幫你。
#
# 但也不是全部都要自己來——UTF-8 是**自同步**編碼，續接位元組一定是 10xxxxxx，
# 不可能跟 ASCII 撞。所以：
#   ✓ 用 ASCII 當分隔符的 string/split、string/find、string/has-prefix? 都是安全的
#   ✓ 比較相等、當 table 的 key、丟進 JSON，都安全
#   ✗ 只有「按位元組位移切片 / 取第 n 個字 / 算寬度」需要 rune 層的工具

(import spork/utf8)

(defn h [s] (printf "\n── %s" s))

# ── rune 層的基本工具（spork/utf8 只給了三個原語，其餘自己疊）─────────
(defn rune-width
  "看第一個位元組就知道這個字元佔幾個 byte（1～4）。"
  [byte]
  (utf8/prefix->width byte))

(defn runes
  "把字串拆成 @[\"漢\" \"字\" \"a\"] 這樣一個一個字元的陣列。"
  [s]
  (def out @[])
  (var i 0)
  (def n (length s))
  (while (< i n)
    (def w (rune-width (in s i)))
    (array/push out (string (slice s i (min n (+ i w)))))
    (+= i w))
  out)

(defn rune-length
  "字元數（不是位元組數）。"
  [s]
  (length (runes s)))

(defn rune-slice
  "按「字元」切片，語意跟 (slice s a b) 一樣但單位是字元。"
  [s start &opt end]
  (def rs (runes s))
  (string ;(slice rs start (or end (length rs)))))

(defn rune-reverse
  "按字元反轉——直接 (string/reverse s) 會把多位元組字元拆爛。"
  [s]
  (string ;(reverse (runes s))))

(defn rune-at
  "取第 n 個字元（回傳字串，不是數字）。"
  [s n]
  (get (runes s) n))

(defn code-points
  "每個字元的 Unicode 碼位。"
  [s]
  (map |(first (utf8/decode-rune $)) (runes s)))

(defn display-width
  "終端機顯示寬度的粗估：CJK 與全形符號算 2 欄，其餘算 1。
  排版對齊時要用這個，不是 length 也不是 rune-length。"
  [s]
  (reduce (fn [acc cp]
            (+ acc (if (or (<= 0x1100 cp 0x115F)      # 韓文字母
                           (<= 0x2E80 cp 0xA4CF)      # CJK 部首～注音
                           (<= 0xAC00 cp 0xD7A3)      # 韓文音節
                           (<= 0xF900 cp 0xFAFF)      # CJK 相容
                           (<= 0xFF00 cp 0xFF60)      # 全形
                           (<= 0x20000 cp 0x3FFFD))   # 擴充 B 以後
                     2 1)))
          0 (code-points s)))

(defn main [& args]
  (def s (or (get args 1) "漢字abc、café 🌏"))

  (h "位元組 vs 字元")
  (printf "  字串              %s" s)
  (printf "  (length s)        %d  ← ★ 位元組數" (length s))
  (printf "  (rune-length s)   %d  ← 字元數" (rune-length s))
  (printf "  (display-width s) %d  ← 終端機欄數（CJK 算 2）" (display-width s))
  (printf "  (in s 0)          %d  ← 是位元組，不是字元" (in s 0))
  (printf "  (rune-at s 0)     %s" (rune-at s 0))

  (h "拆成字元")
  (printf "  %s" (string/join (runes s) " | "))
  (printf "  每個字幾 bytes：%q" (map length (runes s)))
  (printf "  碼位：%q" (code-points s))

  (h "切片：按字元不按位元組")
  (printf "  (rune-slice s 0 3)  => %s" (rune-slice s 0 3))
  (printf "  (rune-slice s 3)    => %s" (rune-slice s 3))
  (printf "  ★ (slice s 0 3) 直接按位元組切 => %q  ← 可能把字砍一半"
          (string (slice s 0 3)))
  (printf "  ★ (slice s 0 4) => %q" (string (slice s 0 4)))

  (h "反轉")
  (printf "  (rune-reverse s)    => %s" (rune-reverse s))
  (printf "  ★ (string/reverse s) => %q  ← 位元組反轉，字全爛了"
          (string/reverse s))

  (h "切割：ASCII 分隔符是安全的")
  (def csv "姓名,年齡,城市")
  (printf "  (string/split \",\" %s)" csv)
  (printf "    => %s  ✓ UTF-8 自同步，逗號不會出現在多位元組字元中間"
          (string/join (string/split "," csv) " / "))
  (printf "  (string/find \"年\" csv) => %q  ← 回的是「位元組」位移"
          (string/find "年" csv))
  (printf "  用中文當分隔符也行 => %s"
          (string/join (string/split "、" "甲、乙、丙") " / "))

  (h "其他安全的操作")
  (printf "  相等比較        %q" (= "漢字" (string "漢" "字")))
  (printf "  當 table 的 key %q" (get {"漢字" :ok} "漢字"))
  (printf "  has-prefix?     %q" (string/has-prefix? "漢" s))
  (printf "  string/replace  %s" (string/replace "abc" "XYZ" s))
  (printf "  拼接            %s" (string s "・尾巴"))

  (h "★ 不安全的操作（都是按位元組做的）")
  (print "  (slice s a b)      按位元組切 → 用 rune-slice")
  (print "  (string/reverse s) 按位元組反轉 → 用 rune-reverse")
  (print "  (s n) / (in s n)   拿到位元組 → 用 rune-at")
  (print "  (length s)         位元組數 → 用 rune-length")
  (print "  string/ascii-upper / ascii-lower 只動 ASCII（名字就寫明了，中文不受影響）")
  (printf "     實測 %s => %s" s (string/ascii-upper s))

  (h "排版對齊：%-10s 為什麼會歪")
  (each w ["ab" "漢字" "café"]
    (printf "  |%-10s| length=%d rune=%d width=%d"
            w (length w) (rune-length w) (display-width w)))
  (print "  ← printf 的寬度是按「位元組」補的，所以 CJK 會歪。")
  (print "    要對齊自己用 display-width 算該補幾個空格：")
  (defn pad-to [s n]
    (string s (string/repeat " " (max 0 (- n (display-width s))))))
  (each w ["ab" "漢字" "café"]
    (printf "  |%s| ✓" (pad-to w 10)))

  (h "PEG 也認得 UTF-8")
  (printf "  抓開頭連續的多位元組字元 => %s"
          (string (first (peg/match ~(<- (some (range "\x80\xff"))) "漢字abc"))))
  (print "  （PEG 的 range 是位元組層；要精準比對字元，用 runes 拆完再處理）")
  (print))
