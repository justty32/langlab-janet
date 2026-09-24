# 配合 course/10-4-巨集.md
(defn show [x] (print (string/format "%j" x)))

(print "== 函式做不到的事 ==")
(defn my-when-fn [c body] (if c body nil))
(show (my-when-fn false (print "函式版：還是印了")))

(print "== 程式碼就是資料 ==")
(show (type '(+ 1 2)))
(show (type (first '(+ 1 2))))
(show (eval '(+ 1 2)))
(show (eval (tuple '* 6 7)))

(print "== quasiquote 拼程式碼 ==")
(def x 5)
(show '(a b ,x))
(show ~(a b ,x))
(show ~(f ,;[1 2 3]))
(show ~(f [1 2 3]))

(print "== 寫一個 my-when ==")
(defmacro my-when [c & body]
  ~(if ,c (do ,;body)))
(show (my-when false (print "巨集版：不會印")))
(show (my-when true 1 2 3))
(show (macex1 '(my-when (> 3 1) (print "a") (print "b"))))
(show (macex1 '(when (> 3 1) (print "a"))))

(print "== 臨時變數要用 with-syms ==")
(defmacro bad-swap [a b] ~(let [tmp ,a] (set ,a ,b) (set ,b tmp)))
(var p 1) (var q 2)
(bad-swap p q)
(show [p q])
(var tmp 10) (var other 20)
(show (macex1 '(bad-swap tmp other)))
(show (protect (eval (macex1 '(bad-swap tmp other)))))
(defmacro good-swap [a b]
  (with-syms [t] ~(let [,t ,a] (set ,a ,b) (set ,b ,t))))
(pp (macex1 '(good-swap tmp other)))
(good-swap tmp other)
(show [tmp other])

(print "== 什麼時候不該寫巨集 ==")
(show (map my-when [true false]))

(print "== 坑：參數是程式碼不是值 ==")
(defmacro add-macro [a b] (+ a b))
(show (add-macro 1 2))
(show (protect (eval '(add-macro (+ 1 1) 2))))
(defmacro add-code [a b] ~(+ ,a ,b))
(show (macex1 '(add-code (+ 1 1) 2)))
(show (add-code (+ 1 1) 2))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. my-unless
(defmacro my-unless [c & body] ~(if ,c nil (do ,;body)))
(show (macex1 '(my-unless (> 1 3) (print "x"))))
(show (my-unless (> 1 3) :ran))
# 2. twice：函式版拿到的是 print 跑完的 nil，只會印一次
(defmacro twice [body] ~(do ,body ,body))
(twice (print "hi"))
(defn twice-fn [v] v v)
(twice-fn (print "函式版只印一次"))
