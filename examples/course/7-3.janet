# 配合 course/7-3-讀錯誤訊息.md 與 7-3b-尾呼叫與-trace-的坑.md
#   janet examples/course/7-3.janet
# 課文裡「存成 xxx.janet 跑一次」的那幾支會 exit 1，這裡全部用安全的方式重現：
#   parse / compile 錯誤用 (parse) 與 (compile) 隔離，runtime 錯誤用 try 接住。
# trace 走 stderr，先 (flush) 把 stdout 推出去，重導到同一個地方時順序才對得上。

(defn 印trace [e f] (flush) (debug/stacktrace f e ""))

(print "== 先分三類 ==")
(printf "parse error   → %j" (try (parse "(print \"hi\"") ([e] e)))
(printf "compile error → %j" ((compile '(prnt "typo") (curenv)) :error))
(defn greet [name greeting] (print greeting " " name))
(printf "compile error → %j" ((compile '(greet "x") (curenv)) :error))
(printf "runtime error → %j" (try (+ 1 nil) ([e] e)))

(print "== 一個真實的 trace，逐行讀 ==")
(defn 算平均 [nums]
  (/ (sum nums) (length nums)))
(defn 讀分數 [row]
  (def n (get row :score))
  (+ n 0))
(defn 報表 [rows]
  (def 分數們 (map 讀分數 rows))
  (print "平均：" (算平均 分數們)))
(try (報表 [{:score 90} {:name "ming"}])
  ([e f] (印trace e f)))

(print "== 常見訊息對照 ==")
(printf "%j" (protect (+ 1 nil)))
(printf "%j" (protect (math/floor nil)))
(printf "%j" (protect ([1 2] 9)))
(printf "%j" (protect (:a 5)))
(printf "%j" (protect (require "./nope")))

(print "== 尾呼叫會吃掉一層（看 stderr：第一層不見了）==")
(defn 第三層 [x] (error "最裡面炸了"))
(defn 第二層 [x] (+ 1 (第三層 x)))
(defn 第一層 [x] (第二層 x))
(try (第一層 42) ([e f] (印trace e f)))

(print "== 讓呼叫不在尾位置，三層就全在 ==")
(defn 第一層-完整 [x] (do (第二層 x) nil))
(try (第一層-完整 42) ([e f] (印trace e f)))

(print "== 在程式裡自己印 trace ==")
(defn 裡 [x] (error "壞了"))
(defn 外 [x] (+ 1 (裡 x)))
(try (外 1) ([e f] (debug/stacktrace f e "")))
(print "程式繼續跑")

(print "== 坑：呼叫 nil 的訊息在講參數型別 ==")
(def f nil)
(printf "%j" (protect (f 1)))
(printf "%j" (protect (f 1 2)))

# ---- 練習解答 ----
(print "== 練習 1 ==")
(print "炸在內建的 slurp；你的程式裡最裡面是 app.janet 第 2 行的 載入，呼叫它的是第 6 行的 main。")
(print "boot.janet 的三行（slurp、run-main、cli-main）都是 Janet 自己的，跳過。原因在第一行：data.csv 開不了。")

(print "== 練習 2：修好 crash.janet ==")
(defn 讀分數-修好 [row]
  (def n (get row :score))
  (assert (number? n) (string/format "row missing :score, got %j" row))
  n)
(printf "%j" (protect (map 讀分數-修好 [{:score 90} {:name "ming"}])))

(print "== 練習 3：三層全尾呼叫，trace 只剩兩行（看 stderr）==")
(defn 第二層-尾 [x] (第三層 x))
(defn 第一層-尾 [x] (第二層-尾 x))
(try (第一層-尾 42) ([e f] (印trace e f)))
