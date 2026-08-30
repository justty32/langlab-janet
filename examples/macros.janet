# 配合 docs/08-巨集-macro.md
#
#   janet examples/macros.janet
#
# 巨集在編譯期把程式碼換成別的程式碼。這支檔的重點是
# **每個巨集都把展開結果印出來**——寫巨集卡住時第一件事就是看 macex1。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-32s => %j" 說明 結果))

(節 "程式就是資料，所以巨集就是「吃 AST、吐 AST」")
(秀 "'(+ 1 2) 的型別" (type '(+ 1 2)))
(秀 "它的內容" '(+ 1 2))
(秀 "第 0 格是什麼" (get '(+ 1 2) 0))
(print "  一段程式碼就是一個 tuple——所以拿它來組合、改寫都是普通的資料操作")

(節 "四個符號")
(def c 'x)
(def body '[(foo) (bar)])
(秀 "'(if c body)      純引用" '(if c body))
(秀 "~(if ,c ,body)    挖一個洞" ~(if ,c ,body))
(秀 "~(if ,c (do ,;body)) 攤平" ~(if ,c (do ,;body)))
(print "  ,  = 這裡要求值後填進來")
(print "  ,; = 挖洞並把序列攤平（不是塞一整個陣列進去）")

(節 "定義巨集，並看它展開成什麼")
(defmacro my-when [c & body] ~(if ,c (do ,;body)))
(秀 "(macex1 '(my-when x (foo) (bar)))" (macex1 '(my-when x (foo) (bar))))
(print "  真的跑一次：")
(my-when true (print "    my-when 的 body 跑了"))

(defmacro unless2 [c & body] ~(if ,c nil (do ,;body)))
(秀 "(macex1 '(unless2 x (foo)))" (macex1 '(unless2 x (foo))))
(unless2 false (print "    unless2 的 body 跑了"))

(節 "macex1 展開一層，macex 展開到底")
(defmacro 外層 [x] ~(my-when ,x (print "巢狀")))
(秀 "macex1  只展一層" (macex1 '(外層 true)))
(秀 "macex   展到底" (macex '(外層 true)))

(節 "⚠ 衛生：不用 with-syms 會怎麼壞")
(defmacro 髒swap [a b] ~(let [tmp ,a] (set ,a ,b) (set ,b tmp)))
(var x 1) (var y 2)
(髒swap x y)
(秀 "髒版配一般名字 x y" [x y])
(print "  看起來沒事。但把展開印出來就看到隱患了：")
(秀 "(macex1 '(髒swap tmp z))" (macex1 '(髒swap tmp z)))
(print "    ↑ (let [tmp tmp] …) —— 巨集裡的 tmp 跟使用者的 tmp 撞在一起了")

(var tmp 100) (var z 200)
# 直接寫 (髒swap tmp z) 會讓整支檔編不起來，所以用 compile 隔離起來看
(def r (compile '(髒swap tmp z) (curenv)))
(printf "  %-32s => %s" "使用者剛好也有 tmp"
        (if (table? r) (string "compile error: " (r :error)) "（居然過了）"))
(print "    ↑ let 綁的是常數，所以 (set tmp z) 打不進去")
(print "    ⚠ 注意錯誤訊息完全沒提「巨集撞名」——你得自己想到去看展開")

(節 "with-syms：生一個保證不撞的名字")
(defmacro 淨swap [a b]
  (with-syms [t] ~(let [,t ,a] (set ,a ,b) (set ,b ,t))))
(var tmp2 100) (var z2 200)
(淨swap tmp2 z2)
(秀 "淨版 tmp2 z2  ← 對了" [tmp2 z2])
(秀 "(macex1 '(淨swap tmp2 z2))" (macex1 '(淨swap tmp2 z2)))
(秀 "with-syms 生的名字長這樣" (with-syms [a] a))
(print "  那個 _00000X 不可能跟使用者的變數撞名——這是巨集正確性的標配")

(節 "⚠ ; 是 splice，不是註解")
(秀 "(f ;args) 把陣列攤成參數"
    (let [f (fn [a b] (+ a b)) args @[1 2]] (f ;args)))
(def r2 (compile '(do (print "a") ; (print "b")) (curenv)))
(printf "  %-32s => %s" "把 ; 當註解寫"
        (if (table? r2) (string "compile error: " (r2 :error)) "（沒擋住）"))
(print "  ⚠ 從 Common Lisp / Scheme 過來的人最容易踩——Janet 的註解是 #")

(節 "什麼時候該用巨集")
(print "  ① 需要控制求值時機（參數不能先被求值）：when / unless / and / or")
(print "  ② 想造新語法或 DSL：for / loop / with 本身都是巨集")
(print "  反過來：能用普通函式就別用巨集——函式好測、好組合、能當值傳")
(print "\n  「巨集不能當值傳」講得不夠精確，實測是這樣：")
(秀 "巨集本身的型別" (type my-when))
(秀 "它的 meta :macro" (get (dyn 'my-when) :macro))
(def f my-when)
(秀 "綁出去再呼叫 (f true '(print 1))" (f true '(print 1)))
(秀 "拿去 map" (map my-when [true]))
(print "    ↑ 綁得起來、也叫得動——但你拿到的是**展開後的 AST**，不是執行結果")
(print "    巨集只有寫在呼叫位置、由編譯器展開時才有巨集的效果")
(print "    傳出去之後它就只是一個「回傳程式碼」的普通函式")

(print "\n✓ macros 跑完")
