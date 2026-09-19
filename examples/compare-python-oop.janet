# Python 對照 ③：class、工具鏈、標準函式庫 —— 配合 docs/46e、docs/46f
#
#   janet examples/compare-python-oop.janet

(import spork/path)
(import spork/json)

(defn 節 [t] (print "\n── " t " ──────────────────────────"))
(defn 對 [py jn v] (printf "  py  %s\n  jn  %-38s => %q" py jn v))

(節 "class ＝ 一個放方法的 table（prototype）")
(def Animal
  @{:speak (fn [self] (string (self :name) " 發出聲音"))
    :describe (fn [self] (string "<" (self :kind) " " (self :name) ">"))
    :kind "Animal"})
(defn animal [name] (table/setproto @{:name name} Animal))
(def Dog
  (table/setproto
    @{:speak (fn [self] (string (self :name) " 汪"))
      :kind "Dog"}
    Animal))
(defn dog [name] (table/setproto @{:name name} Dog))
(def 小白 (dog "小白"))

(print "  py  class Animal: def __init__(self, name) / def speak(self)")
(print "      class Dog(Animal): def speak(self): return f'{self.name} 汪'")
(printf "  jn  (:speak 小白)              => %s" (:speak 小白))
(printf "      (:describe 小白)           => %s   繼承自 Animal" (:describe 小白))
(printf "      super().speak() 寫成 ((Animal :speak) self) => %s" ((Animal :speak) 小白))

(節 "isinstance / type")
(defn instance-of? [obj proto]
  (var p (table/getproto obj))
  (while (and p (not= p proto)) (set p (table/getproto p)))
  (truthy? p))
(printf "  py  isinstance(d, Dog) / isinstance(d, Animal)")
(printf "  jn  (instance-of? 小白 Dog) => %q  (instance-of? 小白 Animal) => %q"
        (instance-of? 小白 Dog) (instance-of? 小白 Animal))
(printf "  ⚠ (type 小白) => %q —— 所有物件都是 :table，type 問不出「類別」"
        (type 小白))
(printf "  ⚠ keys 不走原型鏈：(keys 小白) => %q（看不到方法）" (keys 小白))
(printf "     get 才會往上找：(get 小白 :speak) 有東西 => %q"
        (truthy? (get 小白 :speak)))

(節 "duck typing / hasattr")
(defn 叫一聲 [x] (if (get x :speak) (:speak x) "這東西不會叫"))
(printf "  (叫一聲 小白) => %s" (叫一聲 小白))
(printf "  (叫一聲 @{})  => %s   hasattr 就是 get，沒有 AttributeError" (叫一聲 @{}))

(節 "dataclass / namedtuple ＝ struct")
(defn point [x y] {:x x :y y})
(對 "@dataclass(frozen=True)" "(point 1 2)" (point 1 2))
(對 "p1 == p2 比內容" "(= {:x 1 :y 2} {:y 2 :x 1})" (= {:x 1 :y 2} {:y 2 :x 1}))
(printf "  ⚠ 對可變的 table 就不是了：(= @{:x 1} @{:x 1}) => %q，要 deep= => %q"
        (= @{:x 1} @{:x 1}) (deep= @{:x 1} @{:x 1}))

(節 "if __name__ == '__main__'")
(print "  py  if __name__ == '__main__': main(sys.argv)")
(print "  jn  (defn main [& args] ...)  被 import 時不會跑")
(printf "  (dyn :args)       => %q" (dyn :args))
(printf "  (dyn :executable) => %s" (dyn :executable))
(print "  ⚠ args 的第 0 個是腳本自己的路徑，真正的參數從第 1 個開始")

(節 "標準函式庫：pathlib / os.path")
(對 "os.path.join('a','b','c.txt')" "(path/join \"a\" \"b\" \"c.txt\")"
    (path/join "a" "b" "c.txt"))
(對 "Path(p).suffix" "(path/ext \"x/y.txt\")" (path/ext "x/y.txt"))
(對 "Path(p).name" "(path/basename \"x/y.txt\")" (path/basename "x/y.txt"))
(對 "os.path.dirname(p)" "(path/dirname \"x/y.txt\")" (path/dirname "x/y.txt"))

(節 "json")
(對 "json.loads(s)" "(json/decode \"{\\\"a\\\":1}\")" (json/decode "{\"a\":1}"))
(對 "（要 keyword key）" "(json/decode s true)" (json/decode "{\"a\":1}" true))
(對 "json.dumps(d)" "(json/encode {:a [1 2]})" (json/encode {:a [1 2]}))
(print "  ⚠ decode 預設給的是字串 key，第二個參數 true 才轉成 keyword")

(節 "re ＝ PEG")
(printf "  py  re.search(r'[a-z]+', s)")
(printf "  jn  (peg/find ~(some (range \"az\")) \"12abc\") => %q"
        (peg/find ~(some (range "az")) "12abc"))
(printf "      (peg/match ~(* (<- (some (range \"09\"))) \"-\" (<- (some (range \"09\")))) \"12-34\")")
(printf "      => %q"
        (peg/match ~(* (<- (some (range "09"))) "-" (<- (some (range "09")))) "12-34"))
(printf "      (peg/replace-all ~(set \"aeiou\") \"*\" \"hello\") => %q"
        (string (peg/replace-all ~(set "aeiou") "*" "hello")))
(print "  ⚠ 沒有內建 regex；spork/regex 是把 regex 語法轉成 PEG 的糖衣，功能是子集")

(節 "datetime ＝ os/date（⚠ 月與日是 0-based）")
(對 "datetime.utcfromtimestamp(0)" "(os/date 0)" (os/date 0))
(對 "strftime" "(os/strftime \"%Y-%m-%d\" 0)" (os/strftime "%Y-%m-%d" 0))
(printf "  ⚠ :month 0 是一月、:month-day 0 是一號；(os/strftime \"%%Y-%%m-%%d\" %d) => %s"
        (os/mktime {:year 2026 :month 0 :month-day 0} true)
        (os/strftime "%Y-%m-%d" (os/mktime {:year 2026 :month 0 :month-day 0} true) true))

(節 "random ＝ math/rng")
(def r (math/rng 42))
(printf "  py  random.seed(42); random.randint(0, 99)")
(printf "  jn  (math/rng-int (math/rng 42) 100) 連抽兩次 => %q %q"
        (math/rng-int r 100) (math/rng-int r 100))
(print "  ⚠ math/random 的預設種子是固定的，不設種子每次跑結果一樣")

(節 "subprocess ＝ os/spawn")
(def 子 (os/spawn [(dyn :executable) "-e" "(print :我是子行程)"] :p {:out :pipe}))
(def 輸出 (:read (子 :out) :all))
(def 碼 (os/proc-wait 子))
(printf "  py  subprocess.run([...], capture_output=True)")
(printf "  jn  (os/spawn [...] :p {:out :pipe}) → %s，exit code %q"
        (string/trim (string 輸出)) 碼)

(節 "print(..., file=sys.stderr)")
(eprint "  這一行走的是 stderr（把 2> 導掉就看不到）")
(print "  jn  (eprint x) / (eprintf fmt ...)")

(print "\n完整說明：docs/46e-Python-錯誤與物件.md、docs/46f-Python-工具鏈.md")
