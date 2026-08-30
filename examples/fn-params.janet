# 配合 docs/33-函式參數與閉包.md
#
#   janet examples/fn-params.janet
#
# 五種參數形式、arity 何時被擋、閉包到底捕獲了什麼。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-32s => %j" 說明 結果))

(節 "五種參數形式")
(defn p1 [x y]                [x y])
(defn p2 [x &opt y]           [x y])
(defn p3 [x & rest]           [x rest])
(defn p4 [x &named port host] [x port host])
(defn p5 [x &keys kw]         [x kw])

(秀 "[x y]        (p1 1 2)"          (p1 1 2))
(秀 "[x &opt y]   (p2 1)"            (p2 1))
(秀 "[x &opt y]   (p2 1 2)"          (p2 1 2))
(秀 "[x & rest]   (p3 1 2 3)"        (p3 1 2 3))
(秀 "[x & rest]   (p3 1)  ← 空 tuple" (p3 1))
(秀 "&named  (p4 1 :port 80)"        (p4 1 :port 80))
(秀 "&keys   (p5 1 :port 80 :host …)" (p5 1 :port 80 :host "h"))
(printf "  & rest 收到的型別是 %s，不是 array" (type (get (p3 1 2 3) 1)))

(節 "&opt 沒有預設值語法，要用 default")
(defn 有預設 [x &opt y] (default y 99) [x y])
(秀 "(有預設 1)"        (有預設 1))
(秀 "(有預設 1 2)"      (有預設 1 2))
(秀 "(有預設 1 nil)"    (有預設 1 nil))
(print "  ⚠ default 看的是「值是不是 nil」，不是「有沒有傳」——明確傳 nil 也會被補掉")

(節 "⚠ arity 是編譯期檢查，try 攔不到")
# 直接寫 (p1 1) 會讓整支檔編不起來，所以這裡用 compile 把它隔離起來看
(def 結果 (compile '(p1 1) (curenv)))
(if (table? 結果)
  (printf "  (p1 1) 連編都編不過：%s" (結果 :error))
  (print "  （這個 Janet 版本沒擋住，值得記一筆）"))
(printf "  同一件事透過 apply 動態呼叫 → 變成執行期錯，try 才攔得到：\n    %j"
        (try (apply p1 [1]) ([e] e)))
(print "  ⚠ 訊息裡的 expected N 報的是最大 arity，可選參數也算進去")

(節 "閉包捕獲的是綁定，不是當下的值")
(defn 做計數器 [] (var n 0) (fn [] (++ n)))
(def c1 (做計數器))
(def c2 (做計數器))
(秀 "c1 連叫三次" [(c1) (c1) (c1)])
(秀 "c2 叫一次 ← 各自一份" (c2))
(print "  做計數器 回傳後那個 n 照樣活著（GC 幫你留著）")
(print "  同樣的寫法在 C++ 是對區域變數用 [&] 再回傳 lambda——那是 UB")

(節 "⚠ 迴圈裡建閉包：loop/seq 每圈一份，var+while 全體共用")
(def fs (seq [i :range [0 3]] (fn [] i)))
(秀 "seq 建的三個閉包" (map |($) fs))

(def gs @[])
(var j 0)
(while (< j 3) (array/push gs (fn [] j)) (++ j))
(秀 "var + while 建的三個閉包" (map |($) gs))
(print "  ↑ 全是 3——三個閉包抓的是同一格 j，跑完就都看到終值")

(def hs @[])
(var k 0)
(while (< k 3) (array/push hs (let [m k] (fn [] m))) (++ k))
(秀 "圈內 let 複製一份就對了" (map |($) hs))

(節 "短函式 |")
(秀 "(map |(+ $ 1) [1 2 3])" (map |(+ $ 1) [1 2 3]))
(秀 "(|(+ $0 $1) 3 4)"       (|(+ $0 $1) 3 4))
(秀 "(map |$ [1 2]) ← 恆等"  (map |$ [1 2]))

(節 "defn- 與 docstring")
(defn- 內部用 [] :x)
(defn 有文件 "這是說明" [x] x)
(秀 "內部用 的 :private" (get (dyn '內部用) :private))
(秀 "有文件 的 :private" (get (dyn '有文件) :private))
(print "  有文件 的 :doc（Janet 自動把簽名接在最前面）：")
(each l (string/split "\n" (get (dyn '有文件) :doc)) (print "    " l))

(print "\n✓ fn-params 跑完")
