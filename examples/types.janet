# 配合 docs/38-型別全表.md
#
#   janet examples/types.janet
#
# 把每個型別造出來、問它 (type …)，再看傘狀判斷函式各罩住誰。

(defn 節 [t] (print "\n── " t " ─────────────────────"))

(def 樣本
  [["nil"        nil]
   ["true"       true]
   ["1"          1]
   ["1.5"        1.5]
   ["\"s\""      "s"]
   ["@\"b\""     @"b"]
   ["'sym"       'sym]
   [":kw"        :kw]
   ["[1]"        [1]]
   ["@[1]"       @[1]]
   ["{:a 1}"     {:a 1}]
   ["@{:a 1}"    @{:a 1}]
   ["(fn [] 1)"  (fn [] 1)]
   ["print"      print]
   ["fiber"      (fiber/new (fn [] 1))]
   ["peg"        (peg/compile 1)]
   ["rng"        (math/rng)]
   ["stdout"     stdout]
   ["(int/s64 1)" (int/s64 1)]])

(節 "(type x) 會回什麼")
(each [n v] 樣本 (printf "  %-14s → %j" n (type v)))
(print "  ⚠ nil 有自己的型別 :nil，不是「沒有型別」")
(print "  ⚠ core/ 前綴的就是 abstract type：C 那邊實作、這邊只拿到把手")

(節 "傘狀判斷函式各罩住誰")
(each [nm p] [["bytes?"      bytes?]
              ["indexed?"    indexed?]
              ["dictionary?" dictionary?]
              ["lengthable?" lengthable?]
              ["abstract?"   abstract?]]
  (def 罩住 (filter (fn [[n v]] (truthy? (p v))) 樣本))
  (printf "  %-12s %s" nm (string/join (map first 罩住) "  ")))
(print "  ⚠ bytes? 包含 keyword 和 symbol——要「真的是字串」請用 string?")

(節 "⚠ 沒有 callable?：可呼叫的比 function? 廣")
(printf "  (function? \"abc\") => %j" (function? "abc"))
(printf "  (\"abc\" 1)         => %j   ← 但它真的可以被呼叫（索引自己）" ("abc" 1))
(printf "  ({:a 9} :a)       => %j" ({:a 9} :a))
(print "  要「真的是函式」→ (or (function? f) (cfunction? f))")
(print "  要「能放在呼叫位置」→ 再加 bytes? / indexed? / dictionary?")

(節 "⚠ int? 與 nat? 問的不是型別，是「塞不塞得進 32-bit 有號整數」")
(each [說明 v] [["1" 1] ["1.0" 1.0] ["1.5" 1.5] ["3000000000" 3000000000] ["-1" -1] ["0" 0]]
  (printf "  %-12s int?=%-5j nat?=%-5j" 說明 (int? v) (nat? v)))
(print "  1.0 是 true——全部數字都是 double，1.0 跟 1 在型別上沒差別")
(print "  三十億是 false——它明明是整數，只是塞不進 32-bit")
(printf "  要問「數學上是不是整數」用 (= x (math/floor x)) → 1.0:%j 1.5:%j"
        (= 1.0 (math/floor 1.0)) (= 1.5 (math/floor 1.5)))

(節 "型別轉換")
(printf "  %-28s => %j" "(scan-number \"42\")"   (scan-number "42"))
(printf "  %-28s => %j" "(scan-number \"abc\")"  (scan-number "abc"))
(print  "    ↑ 失敗回 nil，不是拋錯")
(printf "  %-28s => %j" "(string 42)"           (string 42))
(printf "  %-28s => %j" "(string @\"buf\")"      (string @"buf"))
(printf "  %-28s => %j" "(symbol \"s\")"         (symbol "s"))
(printf "  %-28s => %j" "(keyword \"s\")"        (keyword "s"))
(printf "  %-28s => %j" "(string :kw)"          (string :kw))
(printf "  %-28s => %j" "(keys {:a 1})"         (keys {:a 1}))
(printf "  %-28s => %j" "(pairs {:a 1})"        (pairs {:a 1}))

(節 "⚠ 不會自動轉型")
(printf "  (+ 1 \"1\") → %s" (try (+ 1 "1") ([e] (string e))))
(printf "  要轉就明講：(+ 1 (scan-number \"1\")) => %j" (+ 1 (scan-number "1")))

(print "\n✓ types 跑完")
