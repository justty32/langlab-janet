# 配合 course/2-3-在-REPL-裡自助查.md
# 跑法：janet examples/course/2-3.janet

(print "== doc，看說明 ==")
(doc string/split)                      # 種類、位置、呼叫方式、說明文字

(defn hello "打招呼" [name] (string "hi " name))
(doc hello)                             # function、本檔行號、(hello name)、打招呼

(def x 1)
(doc x)                                 # 有名字、沒 docstring：no documentation found.
(doc nosuch)                            # 名字不存在：symbol nosuch not found.（不拋錯）

(print "== doc 給字串，用片段找名字 ==")
(doc "string/spl")                      # 列出名字含 string/spl 的綁定
# 沒有 apropos：(apropos "x") 會 unknown symbol apropos。
# (doc) 不給參數會列全部 700 多個，這裡不跑。

(print "== all-bindings，拿到名字清單 ==")
(print (length (all-bindings)))                                  # 700 多（隨版本與已定義的名字變）
(pp (filter |(string/has-prefix? "string/sp" $) (all-bindings)))  # @[string/split]

(print "== type，看型別 ==")
(each v [1 "a" :a 'a nil true @[1] [1] @{} {} @"b" (fn [] 1) print]
  (printf "%q -> %j" v (type v)))

(print "== 看定義在哪 ==")
(pp (get (curenv) 'hello))              # :doc（中文被逃逸）、:source-map、:value
(pp (get-in (curenv) ['hello :source-map]))   # (檔名 行 欄)

(print "== 坑：function? 不認 C 函式 ==")
(printf "%j" [(function? print) (cfunction? print) (function? hello)])
# (false true true)

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 找名字含 has- 的，再看其中一個
(doc "has-")
(doc string/has-suffix?)

# 2. 有 docstring 的 double，從 curenv 拿 :doc
(defn double "回傳兩倍" [n] (* 2 n))
(print (get-in (curenv) ['double :doc]))

# 3. 數 os/ 開頭的名字
(print (length (filter |(string/has-prefix? "os/" $) (all-bindings))))
