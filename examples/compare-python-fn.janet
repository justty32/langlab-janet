# Python 對照 ②：函式、decorator、generator、錯誤 —— 配合 docs/46d、docs/46e
#
#   janet examples/compare-python-fn.janet

(defn 節 [t] (print "\n── " t " ──────────────────────────"))
(defn 對 [py jn v] (printf "  py  %s\n  jn  %-38s => %q" py jn v))

(節 "參數")
(defn k [a &opt b] (default b 10) [a b])
(對 "def f(a, b=10)" "(defn k [a &opt b] (default b 10))" [(k 1) (k 1 2)])
(defn star [a & xs] [a xs])
(對 "def f(a, *args)" "(defn star [a & xs] ...)" (star 1 2 3))
(defn kw [&keys m] m)
(對 "def f(**kw)" "(defn kw [&keys m] m)" (kw :x 1 :y 2))
(defn named [&named x y] [x y])
(對 "def f(*, x, y)" "(defn named [&named x y] ...)" (named :x 1 :y 2))
(def [p q] [1 2])
(對 "a, b = t" "(def [p q] [1 2])" [p q])
(def [h & tail] [1 2 3])
(對 "a, *rest = t" "(def [h & tail] [1 2 3])" tail)
(對 "f(*xs)" "(+ ;[1 2 3])" (+ ;[1 2 3]))
(對 "f(**d)" "(kw ;(kvs {:x 1}))" (kw ;(kvs {:x 1})))
(print "  ⚠ 只有一個 splice 符號 ;  要攤字典先 (kvs d) 壓成 [k v k v ...]")

(節 "Python 的可變預設參數陷阱：Janet 沒有")
(defn push-it [x &opt acc] (default acc @[]) (array/push acc x) acc)
(printf "  py  def f(x, acc=[]): acc.append(x); return acc  → 第二次叫會累積")
(printf "  jn  (push-it 1) => %q   (push-it 2) => %q" (push-it 1) (push-it 2))
(print "     default 是每次呼叫才求值，所以不共用")
(def 共用 @[])
(defn trap [x &opt acc] (default acc 共用) (array/push acc x) acc)
(printf "  ⚠ 但把 array 掛在頂層 def 再當預設值就一樣中招：%q %q" (trap 1) (trap 2))

(節 "高階函式")
(對 "map(f, xs)" "(map inc [1 2 3])" (map inc [1 2 3]))
(對 "filter(p, xs)" "(filter even? [1 2 3 4])" (filter even? [1 2 3 4]))
(對 "reduce(f, xs, 0)" "(reduce + 0 [1 2 3])" (reduce + 0 [1 2 3]))
(對 "reduce(f, xs)" "(reduce2 + [1 2 3])" (reduce2 + [1 2 3]))
(對 "itertools.accumulate" "(accumulate + 0 [1 2 3])" (accumulate + 0 [1 2 3]))
(對 "functools.partial(f, 10)" "((partial + 10) 5)" ((partial + 10) 5))
(對 "lambda x: g(h(x))" "((comp inc inc) 1)" ((comp inc inc) 1))
(對 "lambda x: x*2" "(|(* $ 2) 5)" (|(* $ 2) 5))
(對 "lambda a,b: a+b" "(|(+ $0 $1) 1 2)" (|(+ $0 $1) 1 2))
(對 "(f(x), g(x))" "((juxt inc dec) 5)" ((juxt inc dec) 5))
(printf "  ⚠ (function? print) => %q —— 內建是 :cfunction，型別是 %q"
        (function? print) (type print))

(節 "decorator ＝ 把函式包一層")
(defn log-calls [f]
  (fn [& args] (printf "    [log] 呼叫參數 %q" args) (f ;args)))
(def add* (log-calls +))
(print "  py  @log_calls / def add(a,b): ...")
(print "  jn  (def add* (log-calls +))")
(printf "  (add* 1 2) => %q" (add* 1 2))
(defmacro defn-logged [name args & body]
  ~(def ,name (log-calls (fn ,name ,args ,;body))))
(defn-logged mul [a b] (* a b))
(print "  想要寫在定義上面的感覺就用巨集 defn-logged：")
(printf "  (mul 3 4) => %q" (mul 3 4))

(節 "generator / yield ＝ fiber")
(def g (fiber/new (fn [] (each x [1 2 3] (yield (* x x))))))
(print "  py  def g(): for x in [1,2,3]: yield x*x")
(printf "  (resume g) => %q  %q  %q" (resume g) (resume g) (resume g))
(printf "  再 resume 一次 => %q，(fiber/status g) => %q" (resume g) (fiber/status g))
(print "  ⚠ 跑完不是丟 StopIteration，是狀態變成 :dead")
(對 "generator expression 直接餵迴圈"
    "(seq [x :in (generate [i :range [0 3]] i)] x)"
    (seq [x :in (generate [i :range [0 3]] i)] x))

(節 "itertools")
(對 "islice(xs, 2)" "(take 2 [1 2 3])" (take 2 [1 2 3]))
(對 "islice(xs, 2, None)" "(drop 2 [1 2 3])" (drop 2 [1 2 3]))
(對 "takewhile" "(take-while even? [2 4 1])" (take-while even? [2 4 1]))
(對 "dropwhile" "(drop-while even? [2 4 1])" (drop-while even? [2 4 1]))
(對 "chain.from_iterable" "(mapcat identity [[1 2] [3]])" (mapcat identity [[1 2] [3]]))
(對 "range(1, 10, 3)" "(range 1 10 3)" (range 1 10 3))
(對 "chunked(xs, 2)" "(partition 2 [1 2 3 4 5])" (partition 2 [1 2 3 4 5]))
(printf "  ⚠ 切割類回 tuple，map/filter 回 array：%q vs %q"
        (type (take 2 [1 2 3])) (type (map inc [1 2 3])))

(節 "try / except / finally")
(對 "except E as e" "(try (error :boom) ([e] [:caught e]))"
    (try (error :boom) ([e] [:caught e])))
(對 "只想知道成不成功" "(protect (error :boom))" (protect (error :boom)))
(對 "同上，成功的情況" "(protect (+ 1 2))" (protect (+ 1 2)))
(對 "raise ValueError(f'bad {n}')" "(try (errorf \"bad %d\" 7) ([e] e))"
    (try (errorf "bad %d" 7) ([e] e)))

(節 "自訂 exception ＝ 丟一個 table")
(defn throw-http [code] (error {:kind :http-error :code code}))
(defn call []
  (try (throw-http 404)
    ([e] (if (= :http-error (get e :kind)) [:http (e :code)] (error e)))))
(print "  py  class HttpError(Exception): ... / except HttpError as e:")
(print "  jn  (error {:kind :http-error :code 404}) 再自己看 :kind 分流")
(printf "  (call) => %q" (call))
(print "  ⚠ Janet 沒有例外型別階層，try 一律全接；接不住就 (error e) 重丟")

(節 "finally ＝ defer（綁區塊，不是綁 try）")
(def 記 @[])
(defn run []
  (defer (array/push 記 :finally)
    (try (do (array/push 記 :body) :ok) ([e] (array/push 記 :except) :err))))
(printf "  (run) => %q，執行順序 %q" (run) 記)

(節 "traceback")
(def f (fiber/new (fn [] (defn 內層 [] (error "壞了")) (內層)) :e))
(resume f)
(printf "  (fiber/status f) => %q" (fiber/status f))
(printf "  (fiber/last-value f) 就是那個錯誤值，型別 %q" (type (fiber/last-value f)))
(def 堆疊 @"")
(with-dyns [*err* 堆疊] (debug/stacktrace f (fiber/last-value f)))
(printf "  (debug/stacktrace f ...) ＝ traceback.print_exc()：%s"
        (string/trim (string 堆疊)))

(節 "在 Python 會炸、在這裡不炸的")
(printf "  (/ 1 0)            => %s   不是 ZeroDivisionError" (string (/ 1 0)))
(printf "  (get {:a 1} :nope) => %q  不是 KeyError" (get {:a 1} :nope))
(printf "  (get [1 2] 99)     => %q  不是 IndexError" (get [1 2] 99))

(print "\n完整說明：docs/46d-Python-函式.md、docs/46e-Python-錯誤與物件.md")
