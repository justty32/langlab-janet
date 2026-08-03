#!/usr/bin/env janet
# PEG 示範：從最小的 pattern 到能解巢狀結構的具名文法。
# 跑法：janet examples/peg-demo.janet
# 詳解見 docs/14-peg.md

(defn h [s] (printf "\n=== %s" s))

# ── 1) 最小：成功 / 失敗 / 沒有捕獲 ──────────────────────────────────
(h "match 的回傳值")
(printf "  有比到但沒捕獲 => %q  ← ★ 空陣列是「成功」" (peg/match '(some (range "az")) "hello123"))
(printf "  比不到         => %q" (peg/match '(some (range "az")) "123"))
(printf "  有捕獲         => %q" (peg/match '(<- (some (range "az"))) "hello123"))

# ── 2) 組合子：sequence / choice / 重複 ──────────────────────────────
(h "組合子")
(printf "  key=value      => %q"
        (peg/match ~(* (<- (some (range "az"))) "=" (<- (some (range "09")))) "key=42"))
(printf "  擇一（有序）   => %q"
        (peg/match ~(<- (+ "cat" "cattle")) "cattle"))     # ★ 先寫的先贏
(printf "  次數範圍       => %q"
        (peg/match ~(<- (between 2 4 (range "09"))) "12345"))
(printf "  要吃完整串     => %q  ← 沒有 -1 的話 \"12345\" 也會過"
        (peg/match ~(* (<- (some (range "09"))) -1) "123a"))

# ── 3) 捕獲時順手轉型 ───────────────────────────────────────────────
(h "捕獲 + 轉型")
(printf "  轉數字   => %q" (peg/match ~(/ (<- (some (range "09"))) ,scan-number) "42"))
(printf "  轉關鍵字 => %q" (peg/match ~(/ (<- (some (range "az"))) ,keyword) "info"))
(printf "  常數     => %q" (peg/match ~(* "yes" (constant true)) "yes"))
(printf "  分組     => %q"
        (peg/match ~(some (group (* (<- (some (range "az"))) (? ","))))  "a,b,c"))
(printf "  串起來   => %q"
        (peg/match ~(% (some (+ (<- (range "az")) (* "_" (constant ""))))) "a_b_c"))
(printf "  位置     => %q" (peg/match ~(* (some (range "az")) ($)) "abc123"))

# ── 4) 具名文法：規則互相引用，能遞迴 ───────────────────────────────
(h "具名文法：解 IPv4")
(def ip-grammar
  ~{:byte (/ (<- (between 1 3 (range "09"))) ,scan-number)
    :main (* :byte "." :byte "." :byte "." :byte -1)})
(printf "  192.168.1.7 => %q" (peg/match ip-grammar "192.168.1.7"))
(printf "  1.2.3       => %q" (peg/match ip-grammar "1.2.3"))

(h "遞迴：括號配對（regex 做不到）")
(def balanced
  ~{:main (* :expr -1)
    :expr (any (+ (* "(" :expr ")") (if-not (set "()") 1)))})
(each s ["(a(b)c)" "(a(b)c" "((()))" "(()"]
  (printf "  %-10s => %s" s (if (peg/match balanced s) "配對 ✓" "不配對 ✗")))

# ── 5) 實用：解一行 log ─────────────────────────────────────────────
(h "解 log")
(def log-line
  ~{:ws    (any (set " \t"))
    :level (/ (<- (+ "INFO" "WARN" "ERROR")) ,keyword)
    :num   (/ (<- (some (range "09"))) ,scan-number)
    :rest  (<- (any 1))
    :main  (* "[" :num "]" :ws :level :ws :rest)})
(each l ["[1234] ERROR 連不上資料庫" "[7] INFO 開機完成" "壞掉的行"]
  (def m (peg/match log-line l))
  (if m
    (let [[num level rest] m]
      (printf "  %-28s => 編號 %d／等級 %q／訊息 %s" l num level rest))
    (printf "  %-28s => nil（不符合格式）" l)))

# ── 6) 另外三個 API ─────────────────────────────────────────────────
(h "find / find-all / replace-all")
(printf "  find       => %q" (peg/find ~(* "b" "c") "abcabc"))
(printf "  find-all   => %q" (peg/find-all "ab" "abXab"))
(printf "  replace-all => %q  ← ★ 回的是 buffer"
        (peg/replace-all ~(some (range "09")) "#" "a1b22c333"))
(printf "  要字串就包一層 => %q"
        (string (peg/replace-all ~(some (range "09")) "#" "a1b22c333")))

# ── 7) 先編譯，重複用比較快 ─────────────────────────────────────────
(h "peg/compile")
(def compiled (peg/compile ~(* (<- (some (range "az"))) -1)))
(printf "  型別 => %q，之後直接丟給 peg/match" (type compiled))
(printf "  用它比對 => %q" (peg/match compiled "hello"))

# ── 8) 拿來做一個小 CSV 切割器 ──────────────────────────────────────
(h "小 CSV 切割器")
(def csv
  ~{:field  (+ (* "\"" (% (any (+ (* "\"\"" (constant "\"")) (<- (if-not "\"" 1))))) "\"")
               (<- (any (if-not (set ",\n") 1))))
    :line   (* :field (any (* "," :field)))
    :main   (* :line -1)})
(each row ["a,b,c" "1,\"含,逗號\",3" "x,\"他說\"\"嗨\"\"\",z"]
  (printf "  %s\n    => 切成 %d 欄：%s"
          row (length (peg/match csv row))
          (string/join (map string (peg/match csv row)) " | ")))
(print)
