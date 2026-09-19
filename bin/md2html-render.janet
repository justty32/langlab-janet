# md2html-render：區塊樹 → HTML 片段。順便收集標題（給目錄）與 slug（錨點 id，演算法對齊
# wf/tools/check_anchors.py 的 github_heading_slug：去連結／標籤、NFKC 近似、小寫、只留字母數字 - _、空白→-）。
#
# ⚠ 半成品（T4 線中止），現在不會過編：slug 的 letter-cp? 分支還沒寫完（本來要改成
#   保留每個 codepoint 的原始位元組片段直接推回去），peg/replace-all 那行也有 unquote 語法錯。
#   沒有其他檔 import 這支，不影響 jpm test／wf-lint。細節見 wf/workflows/planning.md。

(import ./md2html-inline :as inl)
(import ./md2html-hl :as hl)

(defn- utf8-cps "字串 → codepoint 陣列" [s]
  (def out @[]) (var i 0) (def n (length s))
  (while (< i n)
    (def c (s i))
    (def [len cp] (cond (< c 0x80) [1 c] (< c 0xE0) [2 (band c 0x1F)] (< c 0xF0) [3 (band c 0x0F)] [4 (band c 0x07)]))
    (var v cp)
    (for k 1 len (set v (bor (blshift v 6) (band (or (get s (+ i k)) 0) 0x3F))))
    (array/push out v) (+= i len))
  out)

(defn- letter-cp? "白名單：CJK／假名／注音／韓文／拉丁／希臘／西里爾" [cp]
  (or (<= 0x4E00 cp 0x9FFF) (<= 0x3400 cp 0x4DBF) (<= 0xF900 cp 0xFAFF) (<= 0x20000 cp 0x2FFFF)
      (<= 0x3040 cp 0x30FF) (<= 0x3005 cp 0x3007) (<= 0x3100 cp 0x312F) (<= 0xAC00 cp 0xD7AF)
      (and (<= 0xC0 cp 0x24F) (not= cp 0xD7) (not= cp 0xF7)) (<= 0x370 cp 0x3FF) (<= 0x400 cp 0x4FF)))

(defn slug "標題文字 → 錨點 id（未去重）" [text]
  (def plain (->> text (peg/replace-all ~(* "[" (<- (any (if-not "]" 1))) "](" (any (if-not ")" 1)) ")") ,|$0)
                   (peg/replace-all ~(* "<" (any (if-not ">" 1)) ">") "")))
  (def out @"")
  (each cp (utf8-cps (string plain))
    (cond
      (or (<= 48 cp 57) (<= 97 cp 122) (= cp 45) (= cp 95)) (buffer/push-byte out cp)
      (<= 65 cp 90) (buffer/push-byte out (+ cp 32))
      (or (= cp 32) (= cp 9) (= cp 0x3000)) (buffer/push out "-")
      (<= 0x2460 cp 0x2473) (buffer/push out (string (- cp 0x245F)))
      (<= 0xFF10 cp 0xFF19) (buffer/push-byte out (- cp 0xFEE0))
      (<= 0xFF21 cp 0xFF3A) (buffer/push-byte out (+ 32 (- cp 0xFEE0)))
      (<= 0xFF41 cp 0xFF5A) (buffer/push-byte out (- cp 0xFEE0))
      (letter-cp? cp) (buffer/push out (string/from-bytes ;(seq [b :in (string/bytes (string/format "%s" (string/from-bytes)))] b)))
      nil))
  (string out))
