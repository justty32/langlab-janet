# md2html-parse：把 markdown 文字拆成區塊樹（逐行狀態機，不做行內）。
# 區塊：{:t :h :level :text} {:t :p :text} {:t :code :lang :text} {:t :hr}
#       {:t :quote :blocks} {:t :list :ordered :start :items [[blocks]…]}
#       {:t :table :head :rows} {:t :html :text}
# 只支援本 repo 實際用到的子集：清單不巢狀但可含續行與 fence；引用裡可放 fence。

(def- fence-peg (peg/compile ~(* (<- (any " ")) (<- (at-least 3 "`")) (<- (any (if-not :s 1))) (any :s) -1)))
(def- heading-peg (peg/compile ~(* (<- (between 1 6 "#")) (some " ") (<- (any 1)))))
(def- hr-peg (peg/compile ~(* (+ (at-least 3 "-") (at-least 3 "*") (at-least 3 "_")) (any :s) -1)))
(def- item-peg (peg/compile
  ~(* (<- (any " ")) (+ (* (<- (some :d)) ". ") (* (<- (set "-*+")) " ")) (any " ") (<- (any 1)))))
(def- sep-peg (peg/compile ~(* (any " ") (? "|") (some (* (any " ") (? ":") (some "-") (? ":") (any " ") (? "|"))) (any :s) -1)))
(def- quote-peg (peg/compile ~(* (any " ") ">" (? " ") (<- (any 1)))))

(defn- blank? [l] (= 0 (length (string/trim l))))
(defn- table-row? [l] (string/has-prefix? "|" (string/triml l)))
(defn- indent-of [l] (- (length l) (length (string/triml l))))
(defn- dedent [l n] (string/slice l (min n (indent-of l))))

(defn- block-start? "這行會不會開一個新區塊（拿來結束段落）" [l]
  (or (blank? l) (peg/match fence-peg l) (peg/match heading-peg l) (peg/match hr-peg l)
      (peg/match item-peg l) (string/has-prefix? ">" (string/triml l)) (table-row? l)))

(defn split-cells "表格一列 → cell 字串陣列；跳過 code span 裡的 |，\\| 還原成 |" [line]
  (def s (string/trim line))
  (def body (string/slice s (if (string/has-prefix? "|" s) 1 0)
                          (if (and (> (length s) 1) (string/has-suffix? "|" s) (not= (s (- (length s) 2)) 92)) -2 -1)))
  (def cells @[]) (def cur @"") (var tick 0) (var i 0)
  (while (< i (length body))
    (def c (body i))
    (cond
      (and (= c 92) (= (get body (inc i)) 124)) (do (buffer/push cur "|") (+= i 2))
      (= c 96) (do (var r 0) (while (= (get body (+ i r)) 96) (++ r))
                   (set tick (if (= tick r) 0 (if (= tick 0) r tick)))
                   (buffer/push cur (string/slice body i (+ i r))) (+= i r))
      (and (= c 124) (= tick 0)) (do (array/push cells (string/trim (string cur))) (buffer/clear cur) (++ i))
      (do (buffer/push cur (string/from-bytes c)) (++ i))))
  (array/push cells (string/trim (string cur)))
  cells)

(var parse-blocks nil)

(defn- read-fence "從 i（fence 開頭）讀到收尾，回 [block next-i]" [lines i]
  (def [ind ticks lang] (peg/match fence-peg (lines i)))
  (def n (length ind)) (def body @[]) (var j (inc i))
  (while (and (< j (length lines))
              (not (let [t (string/trim (lines j))] (and (string/has-prefix? ticks t) (all |(= $ 96) t)))))
    (array/push body (dedent (lines j) n)) (++ j))
  [{:t :code :lang lang :text (string/join body "\n")} (min (length lines) (inc j))])

(defn- read-list "從 i（清單項）讀完整個清單，回 [block next-i]" [lines i]
  (def [_ mark] (peg/match item-peg (lines i)))
  (def ordered (truthy? (peg/match ~(some :d) mark)))
  (def items @[]) (var j i)
  (while (< j (length lines))
    (def m (peg/match item-peg (lines j)))
    (unless (and m (= ordered (truthy? (peg/match ~(some :d) (m 1))))) (break))
    (def [ind mk rest] m)
    (def width (+ (length ind) (length mk) 1))
    (def body @[rest]) (++ j)
    (while (< j (length lines))
      (def l (lines j))
      (cond
        (and (not (blank? l)) (>= (indent-of l) 2)) (do (array/push body (dedent l width)) (++ j))
        (and (blank? l) (< (inc j) (length lines)) (not (blank? (lines (inc j))))
             (>= (indent-of (lines (inc j))) 2) (not (peg/match item-peg (lines (inc j)))))
        (do (array/push body "") (++ j))
        (and (blank? l) (< (inc j) (length lines)) (peg/match item-peg (lines (inc j)))) (do (++ j) (break))
        (break)))
    (array/push items (parse-blocks body)))
  [{:t :list :ordered ordered :start (if ordered (scan-number mark) 1) :items items} j])

(defn- read-table [lines i]
  (def head (split-cells (lines i))) (def rows @[]) (var j (+ i 2))
  (while (and (< j (length lines)) (table-row? (lines j)))
    (array/push rows (split-cells (lines j))) (++ j))
  [{:t :table :head head :rows rows} j])

(defn- read-quote [lines i]
  (def body @[]) (var j i)
  (while (and (< j (length lines)) (string/has-prefix? ">" (string/triml (lines j))))
    (array/push body (first (peg/match quote-peg (lines j)))) (++ j))
  [{:t :quote :blocks (parse-blocks body)} j])

(defn- read-para [lines i]
  (def body @[(lines i)]) (var j (inc i))
  (while (and (< j (length lines)) (not (block-start? (lines j))))
    (array/push body (string/trim (lines j))) (++ j))
  [{:t :p :text (string/join body "\n")} j])

(set parse-blocks (fn parse-blocks [lines]
  (def out @[]) (var i 0) (def n (length lines))
  (while (< i n)
    (def l (lines i))
    (def [blk next]
      (cond
        (blank? l) [nil (inc i)]
        (peg/match fence-peg l) (read-fence lines i)
        (peg/match heading-peg l)
        (let [[hs text] (peg/match heading-peg l)] [{:t :h :level (length hs) :text (string/trim text)} (inc i)])
        (peg/match hr-peg l) [{:t :hr} (inc i)]
        (string/has-prefix? "<!--" l) [{:t :html :text l} (inc i)]
        (peg/match item-peg l) (read-list lines i)
        (string/has-prefix? ">" (string/triml l)) (read-quote lines i)
        (and (table-row? l) (< (inc i) n) (peg/match sep-peg (lines (inc i)))) (read-table lines i)
        (read-para lines i)))
    (when blk (array/push out blk))
    (set i (max next (inc i))))
  out))

(defn parse "markdown 全文 → 區塊陣列" [text]
  (parse-blocks (string/split "\n" (string/replace-all "\r\n" "\n" text))))
