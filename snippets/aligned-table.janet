#!/usr/bin/env janet
# 印出「中文也對得齊」的表格。
# 跑法：janet snippets/aligned-table.janet
#
# 為什麼要這支：printf 的 %-10s 數的是**位元組**，但中文字在終端機佔**兩格**寬，
# 所以只要有中文欄位，框線一定歪。三個數字全都不一樣：
#     "中文abc"  → length(byte) 9   字元數 5   顯示寬度 7
# 解法是 spork/rawterm 的 monowidth（顯示寬度），自己補空白。
# 詳解見 docs/41-spork-終端與-shell.md；問題本身記在 docs/28b。

(import spork/rawterm)

# ── 三個基本工具 ──────────────────────────────────────────────
(defn 寬 [s] (rawterm/monowidth (string s)))

(defn 靠左 [s w]
  "把 s 補到顯示寬度 w（不足補空白，超過原樣回傳）。"
  (def s (string s))
  (string s (string/repeat " " (max 0 (- w (寬 s))))))

(defn 靠右 [s w]
  (def s (string s))
  (string (string/repeat " " (max 0 (- w (寬 s)))) s))

(defn 截斷 [s w]
  "按顯示寬度截斷，不會把中文字切一半。"
  (def s (string s))
  (if (<= (寬 s) w) s (string (rawterm/slice-monowidth s (- w 1)) "…")))

# ── 表格 ─────────────────────────────────────────────────────
(defn 表格
  ``印一張對齊的表格。
  rows 是「陣列的陣列」，第一列當表頭。
  aligns 可省略，給的話是每欄的 :left / :right。``
  [rows &opt aligns]
  (default aligns (map (fn [_] :left) (first rows)))
  # 每欄取最寬的那格
  (def 欄寬
    (seq [i :range [0 (length (first rows))]]
      (max ;(map |(寬 (get $ i "")) rows))))
  (defn 一列 [r]
    (string "│ "
            (string/join
              (seq [[i cell] :pairs r]
                (def w (get 欄寬 i))
                (if (= :right (get aligns i)) (靠右 cell w) (靠左 cell w)))
              " │ ")
            " │"))
  (defn 分隔 [左 中 右]
    (string 左 (string/join (map |(string/repeat "─" (+ 2 $)) 欄寬) 中) 右))
  (print (分隔 "┌" "┬" "┐"))
  (print (一列 (first rows)))
  (print (分隔 "├" "┼" "┤"))
  (each r (drop 1 rows) (print (一列 r)))
  (print (分隔 "└" "┴" "┘")))

# ── 示範 ─────────────────────────────────────────────────────
(defn main [&]
  (print "\n三個長度都不一樣：")
  (each s ["abc" "中文" "中文abc" "日本語です"]
    (printf "  %-14s byte=%-3d 顯示寬=%d" s (length s) (寬 s)))

  (print "\n❌ 用 printf 的 %-12s（數 byte，中文欄會歪）：")
  (each [a b] [["名稱" "說明"] ["janet" "直譯器"] ["spork" "準標準庫"] ["jpm" "套件管理"]]
    (printf "  |%-12s|%-12s|" a b))

  (print "\n✅ 用 monowidth 補（對齊）：")
  (表格 [["名稱" "說明" "大小"]
         ["janet" "直譯器與 REPL" "1.2 MB"]
         ["spork" "準標準庫（51 模組）" "800 KB"]
         ["jpm" "套件管理／build" "60 KB"]]
        [:left :left :right])

  (print "\n截斷（不會把中文切一半）：")
  (each w [4 6 9]
    (printf "  截到 %d 格：%s" w (截斷 "日本語です" w)))
  (print "\n✓ aligned-table 跑完"))
