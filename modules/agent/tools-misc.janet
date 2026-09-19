# now 與 calc —— 兩個不碰外界的小工具。
#
# calc 用 PEG 自己解四則運算（+ - * / % ^ 與括號），**不是 eval**：模型給什麼字串進來
# 都只會被當算式看，塞 Janet 程式碼進來也只會得到「算式看不懂」。

(import ./registry :as reg)

(defn- fold-ops
  "PEG 捕捉出來的是 [值 運算子 值 運算子 值 …]，從左到右折起來（同一層優先序）。"
  [& xs]
  (var acc (first xs))
  (var i 1)
  (while (< i (length xs))
    (def op (xs i))
    (def v (xs (+ i 1)))
    (set acc
         (case op
           "+" (+ acc v)
           "-" (- acc v)
           "*" (* acc v)
           "/" (if (= v 0) (error "除以零") (/ acc v))
           "%" (if (= v 0) (error "除以零") (% acc v))
           "^" (math/pow acc v)))
    (+= i 2))
  acc)

(def calc-peg
  "算式文法：優先序由低到高是 expr(+ -) → term(* / %) → pow(^) → atom(數字／括號)。"
  (peg/compile
    ~{:ws   (any (set " \t"))
      :num  (/ (<- (* (? "-") :d+ (? (* "." :d+)))) ,scan-number)
      :atom (* :ws (+ :num (* "(" :expr ")")) :ws)
      :pow  (/ (* :atom (any (* (<- "^") :atom))) ,fold-ops)
      :term (/ (* :pow (any (* (<- (set "*/%")) :pow))) ,fold-ops)
      :expr (/ (* :term (any (* (<- (set "+-")) :term))) ,fold-ops)
      :main (* :expr -1)}))

(defn calc
  ``算一段四則運算字串，回數字；看不懂或除以零就丟中文錯誤。
    (calc "1+2*3")     # => 7
    (calc "(1+2)*3")   # => 9
    (calc "2^10")      # => 1024``
  [expr]
  (def s (string (or expr "")))
  (def m (peg/match calc-peg s))
  (when (nil? m)
    (error (string "算式看不懂：「" s "」（只支援數字、+ - * / % ^ 與括號）")))
  (first m))

(defn- fmt-number
  "整數就印整數，不要 7.0。"
  [n]
  (if (= n (math/floor n)) (string/format "%d" (math/floor n)) (string n)))

(def calc-tool
  "calc 工具：算四則運算。"
  (reg/make-tool "calc"
    "計算一段四則運算（支援 + - * / % ^ 與括號），例如 \"(12+3)*4\"。"
    {:type "object"
     :properties {:expression {:type "string" :description "算式"}}
     :required ["expression"]}
    (fn [args] (fmt-number (calc (get args :expression))))))

(defn now-string
  "目前 UTC 時間，ISO 8601 形狀。⚠ os/date 的 :month／:month-day 是 0 起算，要 +1。"
  []
  (def d (os/date (os/time) true))
  (string/format "%04d-%02d-%02dT%02d:%02d:%02dZ"
                 (d :year) (inc (d :month)) (inc (d :month-day))
                 (d :hours) (d :minutes) (d :seconds)))

(def now-tool
  "now 工具：回目前 UTC 時間。"
  (reg/make-tool "now"
    "取得目前的 UTC 時間（ISO 8601）。"
    {:type "object" :properties {} :required []}
    (fn [_] (now-string))))
