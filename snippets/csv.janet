#!/usr/bin/env janet
# 讀寫 CSV——正確處理引號、欄位內的逗號與換行。
# 跑法：janet snippets/csv.janet
#
# 為什麼不能用 (string/split "," 一行)：
#   a,"b,c",d   → 會被切成四欄，而正確答案是三欄
#   a,"含""引號",c → 兩個雙引號代表一個雙引號，split 完全不懂
#   欄位裡還可能有換行，那樣連「一行一筆」都不成立
# 所以用內建 PEG（docs/14）——它本來就是為這種事準備的。

# ── 讀 ───────────────────────────────────────────────────────
(def 一列-peg
  ~{# 引號欄：兩個雙引號 "" 代表一個字面的 "；其餘直到收尾的 " 都照收
    :引號欄 (* `"` (% (any (+ (/ `""` `"`) (<- (if-not `"` 1))))) `"`)
    # 裸欄：吃到逗號或換行為止（可以是空的）
    :裸欄   (<- (any (if-not (set ",\n\r") 1)))
    :欄     (+ :引號欄 :裸欄)
    :main   (* :欄 (any (* "," :欄)))})

(def 一列 (peg/compile 一列-peg))

# 整份：先把「不在引號裡的換行」當列分隔，再逐列解析。
# ⚠ 直接 (string/split "\n") 會切壞含換行的引號欄，所以列的切割也交給 PEG。
(def 整份
  (peg/compile
    ~{:引號欄 (* `"` (any (+ `""` (if-not `"` 1))) `"`)
      :裸欄   (any (if-not (set ",\n\r") 1))
      :欄     (+ :引號欄 :裸欄)
      :列     (<- (* :欄 (any (* "," :欄))))
      :換行   (+ "\r\n" "\n" "\r")
      :main   (* :列 (any (* :換行 :列)) (? :換行))}))

(defn 解析
  ``CSV 字串 → @[@[欄…] …]。``
  [文字]
  (def 列們 (or (peg/match 整份 文字) @[]))
  (seq [l :in 列們 :when (not (empty? l))] (peg/match 一列 l)))

(defn 解析-具名
  "第一列當表頭，回 @[@{表頭 值 …} …]。"
  [文字]
  (def rows (解析 文字))
  (if (empty? rows) @[]
    (let [表頭 (map keyword (first rows))]
      (seq [r :in (drop 1 rows)]
        (tabseq [[i k] :pairs 表頭] k (get r i ""))))))

# ── 寫 ───────────────────────────────────────────────────────
(defn 跳脫欄
  ``需要引號才加引號：含 , " 換行 或前後有空白時。
  ⚠ 引號內的 " 要寫成 ""。``
  [v]
  (def s (string v))
  (if (or (string/find "," s) (string/find `"` s)
          (string/find "\n" s) (string/find "\r" s)
          (not= s (string/trim s)))
    (string `"` (string/replace-all `"` `""` s) `"`)
    s))

(defn 寫一列 [欄們] (string/join (map 跳脫欄 欄們) ","))

(defn 寫
  "@[@[欄…] …] → CSV 字串（用 \\n 換行）。"
  [rows]
  (string (string/join (map 寫一列 rows) "\n") "\n"))

# ── 示範 ─────────────────────────────────────────────────────
(defn main [&]
  (print "\n── ① 為什麼 string/split 不夠 ──────────────────")
  (def 難搞 `a,"b,c",d`)
  (printf "  原文            %s" 難搞)
  (printf "  string/split ,  => %j  ← 四欄，錯了" (string/split "," 難搞))
  (printf "  PEG             => %j  ← 三欄" (peg/match 一列 難搞))

  (print "\n── ② 四種難處 ──────────────────")
  (each [說明 s] [["含逗號"       `a,"b,含逗號",c`]
                  ["跳脫的引號"   `a,"含""引號",c`]
                  ["空欄"         `x,,z`]
                  ["前後空白"     `a, b ,c`]]
    (printf "  %-12s %-22s => %s" 說明 s
            (string/join (map |(string/format "[%s]" $) (peg/match 一列 s)) " ")))

  (print "\n── ③ 欄位裡有換行 ──────────────────")
  (def 多行 (string "id,note\n1,\"第一行\n第二行\"\n2,普通\n"))
  (printf "  原文共 %d 個換行字元，但只有 %d 筆資料列"
          (length (filter |(= 10 $) (string/bytes 多行))) (dec (length (解析 多行))))
  # ⚠ 用 %s 不用 %j：中文在 %j 下會被逃逸（docs/01）；換行也換成 ⏎ 才看得出來
  (each r (解析 多行)
    (printf "    %s" (string/join
                       (map |(string/format "[%s]" (string/replace-all "\n" "⏎" (string $))) r)
                       " ")))
  (print "  ↑ 直接 (string/split \"\\n\") 會把第 1 筆切成兩半")

  (print "\n── ④ 具名（第一列當表頭）──────────────────")
  (def 資料 "name,age,city\nAlice,30,台北\nBob,25,\"高雄, 前鎮\"\n")
  (each r (解析-具名 資料)
    (printf "    %s（%s 歲）住 %s" (r :name) (r :age) (r :city)))

  (print "\n── ⑤ 寫出去，而且讀得回來 ──────────────────")
  (def 原始 @[@["name" "note"]
              @["Alice" `他說 "嗨"`]
              @["Bob" "含,逗號"]
              @["Carol" "第一行\n第二行"]
              @["Dave" " 前後空白 "]])
  (def 文字 (寫 原始))
  (print "  寫出來：")
  (each l (string/split "\n" (string/trimr 文字)) (print "    " l))
  (def 讀回 (解析 文字))
  (printf "  round-trip 一致？%j"
          (deep= (map |(map string $) 原始) (map |(map string $) 讀回)))
  (print "  ↑ 這是這支片段最該通過的一條測試")

  (print "\n✓ csv 跑完"))
