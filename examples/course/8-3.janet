# 配合 course/8-3-命令列參數.md
(import spork/argparse :as ap)

(print "== 最原始的拿法：dyn *args* ==")
(print (string/format "%j" (dyn *args*)))
# 帶參數跑看看：janet examples/course/8-3.janet 3 hello --x

(print "== 請 argparse 幫你解析 ==")
(def res
  (ap/argparse "示範：跟人打招呼"
    :args ["demo" "-n" "Alice" "--name" "Bob" "--upper" "-vv" "a.txt" "b.txt"]
    "name"    {:kind :accumulate :short "n" :help "名字，可重複給"}
    "upper"   {:kind :flag       :short "u" :help "轉大寫"}
    "verbose" {:kind :multi      :short "v" :help "多給幾次多囉嗦幾分"}
    "level"   {:kind :option     :short "l" :default "1" :help "等級"}
    :default  {:kind :accumulate :help "檔名"}))
(printf "name     %j" (res "name"))
(printf "upper    %j" (res "upper"))
(printf "verbose  %j" (res "verbose"))
(printf "level    %j" (res "level"))
(printf ":default %j" (res :default))

(print "== 沒給的選項會拿到什麼 ==")
(def res2
  (ap/argparse "示範" :args ["demo"]
    "upper"  {:kind :flag}
    "level"  {:kind :option :default "1"}
    :default {:kind :accumulate}))
(printf "upper    %j" (res2 "upper"))
(printf "level    %j" (res2 "level"))
(printf ":default %j" (res2 :default))
(printf "補成空的 %j" (or (res2 :default) @[]))

(print "== --help 免費送 ==")
(def res3
  (ap/argparse "示範：跟人打招呼" :args ["demo" "--help"]
    "name" {:kind :option :short "n" :help "名字"}))
(printf "回傳值 %j" res3)

(print "== 值都是字串，要數字自己轉 ==")
(def res4
  (ap/argparse "示範" :args ["demo" "-l" "5"]
    "level" {:kind :option :short "l" :map scan-number}))
(printf "level %j，加一是 %j" (res4 "level") (+ 1 (res4 "level")))

(print "== 坑：單獨的 - 被吃掉 ==")
(def res5 (ap/argparse "示範" :args ["demo" "a" "-"] :default {:kind :accumulate}))
(printf ":default %j" (res5 :default))

(print "== 坑：option 是字串 ==")
(def res6 (ap/argparse "示範" :args ["demo" "-l" "5"] "level" {:kind :option :short "l"}))
(printf "%j" (protect (+ 1 (res6 "level"))))

(print "== 真的接上命令列 ==")
# 這段沒有 :args，讀的是真正的 (dyn :args)。不帶參數也能跑。
# 試試：janet examples/course/8-3.janet -n Bob --upper x.txt
(def real
  (ap/argparse "8-3 範例：跟人打招呼"
    "name"  {:kind :accumulate :short "n" :help "名字，可重複給"}
    "upper" {:kind :flag       :short "u" :help "轉大寫"}
    :default {:kind :accumulate :help "檔名"}))
(unless real (os/exit 1))
(def names (or (real "name") @["world"]))
(each n names
  (def line (string "hello, " n))
  (print (if (real "upper") (string/ascii-upper line) line)))
(printf "檔名：%j" (or (real :default) @[]))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. repeat 工具：-c 次數（預設 1），位置參數是要印的字
# 2. 加 --quiet，給了就不印，只回傳那些行
(defn repeat-tool [args]
  (def opts
    (ap/argparse "repeat：把字印 N 次" :args ["repeat" ;args]
      "count" {:kind :option :short "c" :default "1" :map scan-number :help "次數"}
      "quiet" {:kind :flag   :short "q" :help "不印，只回傳"}
      :default {:kind :accumulate :help "要印的字"}))
  (unless opts (error "參數不對"))
  (def words (string/join (or (opts :default) @[]) " "))
  (def lines (seq [_ :range [0 (opts "count")]] words))
  (unless (opts "quiet") (each l lines (print l)))
  lines)
(repeat-tool ["-c" "3" "hi"])
(printf "%j" (repeat-tool ["-c" "2" "-q" "bye" "now"]))
