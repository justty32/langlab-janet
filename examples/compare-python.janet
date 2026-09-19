# Python 對照 ①：資料、切片、推導 —— 配合 docs/46b、docs/46c
#
#   janet examples/compare-python.janet
#
# 每一段都是「Python 這樣寫 → Janet 這樣寫 → 真的跑出來長這樣」。
# Python 那行只是註解，不會執行。

(defn 節 [t] (print "\n── " t " ──────────────────────────"))
(defn 對 [py jn v] (printf "  py  %s\n  jn  %-38s => %q" py jn v))

(節 "容器：括號剛好對調")
(對 "[1, 2, 3]   list（可變）" "@[1 2 3]  array" @[1 2 3])
(對 "(1, 2, 3)   tuple（不可變）" "[1 2 3]   tuple" [1 2 3])
(對 "{'a': 1}    dict" "@{:a 1}   table" @{:a 1})
(對 "frozen dict" "{:a 1}    struct" {:a 1})
(print "  ⚠ Janet 用 @ 表示可變；沒 @ 的 [] {} 是不可變的 tuple/struct")

(節 "沒有 set：用 table 的 key 當集合")
(def 集 (tabseq [x :in [1 2 2 3]] x true))
(對 "s = {1, 2, 2, 3}" "(tabseq [x :in xs] x true)" 集)
(對 "2 in s" "(has-key? 集 2)" (has-key? 集 2))
(對 "len(s)" "(length 集)" (length 集))
(對 "list(set(xs))" "(distinct [1 2 2 3])" (distinct [1 2 2 3]))
(def a {1 true 2 true 3 true}) (def b {2 true 3 true 4 true})
(對 "a & b" "(filter |(has-key? b $) (keys a))" (filter |(has-key? b $) (keys a)))

(節 "切片：⚠ 負索引差一格")
(對 "a[1:-2]" "(slice [1 2 3 4 5] 1 -2)" (slice [1 2 3 4 5] 1 -2))
(對 "a[1:]" "(slice [1 2 3 4 5] 1)" (slice [1 2 3 4 5] 1))
(printf "  ⚠ Python 的 a[1:-1] 砍掉最後一個 => %q"
        (let [a [1 2 3 4 5]] (slice a 1 -2)))
(printf "     Janet 的 (slice a 1 -1) 保留到結尾    => %q" (slice [1 2 3 4 5] 1 -1))
(print "     心法：Janet 的負索引是 len+1+n，Python 是 len+n")
(對 "a[::2]" "(seq [i :range [0 6 2]] i)" (seq [i :range [0 6 2]] i))
(對 "(切片回傳型別)" "(type (slice @[1 2 3] 1))" (type (slice @[1 2 3] 1)))

(節 "三種推導")
(對 "[x*x for x in range(5) if x%2==0]"
    "(seq [x :range [0 5] :when (even? x)] (* x x))"
    (seq [x :range [0 5] :when (even? x)] (* x x)))
(對 "{x: x*x for x in [1,2,3]}"
    "(tabseq [x :in [1 2 3]] x (* x x))"
    (tabseq [x :in [1 2 3]] x (* x x)))
(對 "[y for x in xs for y in x]"
    "(catseq [x :in [1 2]] [x x])"
    (catseq [x :in [1 2]] [x x]))
(對 "(x*x for x in range(100))  惰性"
    "(take 3 (generate [x :range [0 100]] (* x x)))"
    (take 3 (generate [x :range [0 100]] (* x x))))
(print "  ⚠ generate 是 Janet 唯一的惰性序列（它是 fiber）；map/filter 全是 eager")

(節 "內建函式")
(對 "enumerate(xs)" "(pairs [:a :b :c])" (pairs [:a :b :c]))
(對 "zip(a, b)" "(map tuple [1 2 3] [:a :b :c])" (map tuple [1 2 3] [:a :b :c]))
(對 "dict(zip(k, v))" "(zipcoll [:a :b] [1 2])" (zipcoll [:a :b] [1 2]))
(對 "sorted(xs, key=len)" "(sorted-by length [\"aaa\" \"b\" \"cc\"])"
    (sorted-by length ["aaa" "b" "cc"]))
(對 "reversed(xs)" "(reverse [1 2 3])" (reverse [1 2 3]))
(對 "sum(xs)" "(sum [1 2 3])" (sum [1 2 3]))
(對 "all(even(x) for x in xs)" "(all even? [2 4])" (all even? [2 4]))
(對 "min(xs)" "(min ;[3 1 2])" (min ;[3 1 2]))
(print "  ⚠ min/max 吃多個參數要 splice；sum/product 反過來吃序列")
(對 "any(...)" "(some even? [1 3 4])" (some even? [1 3 4]))
(對 "next(x for x in xs if even(x))" "(find even? [1 3 4])" (find even? [1 3 4]))
(print "  ⚠ some 回的是述詞的回傳值，要元素本身用 find")

(節 "in / index")
(對 "2 in xs" "(has-value? [1 2 3] 2)" (has-value? [1 2 3] 2))
(對 "xs.index(2)" "(index-of 2 [1 2 3])" (index-of 2 [1 2 3]))
(對 "'ell' in 'hello'" "(string/find \"ell\" \"hello\")" (string/find "ell" "hello"))
(print "  ⚠ index-of 是「值在前」，has-value? 是「序列在前」，順序相反")

(節 "字典方法")
(對 "d.get(k, 0)" "(get {:a 1} :b 0)" (get {:a 1} :b 0))
(對 "d[k]" "({:a 1} :a)" ({:a 1} :a))
(對 "d.items()" "(pairs {:a 1})" (pairs {:a 1}))
(對 "{**a, **b}" "(merge {:a 1} {:b 2})" (merge {:a 1} {:b 2}))
(對 "d[k] += 1（沒有對應語法）" "(update @{:a 1} :a inc)" (update @{:a 1} :a inc))
(對 "Counter(xs)" "(frequencies [:a :b :a])" (frequencies [:a :b :a]))
(對 "groupby（要先排序）" "(group-by |(mod $ 3) [1 2 3 4 5 6])"
    (group-by |(mod $ 3) [1 2 3 4 5 6]))
(對 "itertools.groupby（切相鄰）" "(partition-by even? [2 4 1 3 6])"
    (partition-by even? [2 4 1 3 6]))
(defn ensure [d k mk] (or (get d k) (get (put d k (mk)) k)))
(def dd @{})
(array/push (ensure dd :xs array) 1)
(array/push (ensure dd :xs array) 2)
(對 "defaultdict(list) / setdefault" "(ensure d :xs array)" dd)
(對 "del d[k]" "(put @{:a 1} :a nil)" (put @{:a 1} :a nil))
(print "  ⚠ 值設成 nil 等於刪掉 key，Python 的 d[k]=None 不是這樣")

(節 "字串：⚠ 參數順序幾乎都跟 Python 相反")
(對 "f'{name} has {n}'" "(string/format \"%s has %d\" name n)"
    (string/format "%s has %d" "Bob" 3))
(對 "'a' + str(1)" "(string \"a\" 1 :b)" (string "a" 1 :b))
(對 "','.join(xs)" "(string/join [\"a\" \"b\"] \",\")" (string/join ["a" "b"] ","))
(對 "s.split(',')" "(string/split \",\" \"a,b,c\")" (string/split "," "a,b,c"))
(對 "s.strip()" "(string/trim \"  hi  \")" (string/trim "  hi  "))
(對 "s.startswith('he')" "(string/has-prefix? \"he\" \"hello\")"
    (string/has-prefix? "he" "hello"))
(對 "s.replace('l','L')" "(string/replace-all \"l\" \"L\" \"hello\")"
    (string/replace-all "l" "L" "hello"))
(對 "s.replace('l','L',1)" "(string/replace \"l\" \"L\" \"hello\")"
    (string/replace "l" "L" "hello"))
(對 "s * 3" "(string/repeat \"ab\" 3)" (string/repeat "ab" 3))
(對 "r'C:\\new'" "``C:\\new``（反引號＝多行＋raw）" ``C:\new``)
(printf "  ⚠ (length \"C:\\new\") => %q，反引號版 => %q" (length "C:\new") (length ``C:\new``))

(節 "Python 人一定會踩的四件事")
(printf "  0 / \"\" / @[] 全是真      : %q %q %q" (truthy? 0) (truthy? "") (truthy? @[]))
(printf "  = 對可變容器比身分       : (= @[1] @[1]) => %q，(deep= @[1] @[1]) => %q"
        (= @[1] @[1]) (deep= @[1] @[1]))
(printf "  整數只有 double          : (= 9007199254740993 9007199254740994) => %q"
        (= 9007199254740993 9007199254740994))
(printf "  字串是 bytes             : (length \"héllo\") => %q，(get \"abc\" 0) => %q"
        (length "héllo") (get "abc" 0))
(printf "  除以零不炸               : (/ 1 0) => %s" (string (/ 1 0)))

(print "\n完整說明：docs/46-從-Python-過來.md 系列")
