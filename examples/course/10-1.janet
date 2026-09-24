# 配合 course/10-1-fiber.md
(defn show [x] (print (string/format "%j" x)))

(print "== 建、推、停 ==")
(def f (fiber/new (fn [] (yield 1) (yield 2) (yield 3) :done)))
(show (fiber/status f))
(show (resume f))
(show (resume f))
(show (resume f))
(show (fiber/status f))
(show (resume f))
(show (fiber/status f))
(show (protect (resume f)))

(print "== 當產生器走訪 ==")
(def squares (fiber/new (fn [] (for i 0 5 (yield (* i i))))))
(each x squares (prin x " "))
(print)
(def nums (fiber/new (fn [] (var n 0) (forever (yield (++ n))))))
(show (take 3 nums))
(show (resume nums))

(print "== resume 也能把值送進去 ==")
(def echo (fiber/new (fn [] (def got (yield :ready)) (yield (string "got " got)))))
(show (resume echo))
(show (resume echo "hello"))

(print "== try 其實就是 fiber ==")
(def e (fiber/new (fn [] (error "boom")) :e))
(show (resume e))
(show (fiber/status e))
(show (try (error "boom") ([err] (string "caught " err))))

(print "== 坑：走過一次就沒了 ==")
(def once (fiber/new (fn [] (yield 1) (yield 2))))
(each x once (prin x " "))
(print)
(each x once (prin x " "))
(print "<- 第二次什麼都沒印")
(show (fiber/status once))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 費氏數列產生器
(def fib (fiber/new (fn [] (var a 0) (var b 1) (forever (yield a) (def c (+ a b)) (set a b) (set b c)))))
(show (take 8 fib))
# 2. 送進去一個數字，yield 它的兩倍
(def doubler (fiber/new (fn [] (var x (yield :ready)) (forever (set x (yield (* 2 x)))))))
(resume doubler)
(show (resume doubler 5))
(show (resume doubler 7))
(show (resume doubler 100))
