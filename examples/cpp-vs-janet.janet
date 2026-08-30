# 配合 docs/01b-給-C++-開發者.md
#
#   janet examples/cpp-vs-janet.janet
#
# 每一段的格式都是「C++ 直覺說 X → Janet 實際上 Y」，而且 Y 是真的跑出來的。
# 這五個地方會讓你吃悶虧，看到實際輸出比讀說明有用。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 對照 [題 cpp janet]
  (printf "  %s" 題)
  (printf "    C++ 直覺  : %s" cpp)
  (printf "    Janet 實際: %s" janet))

(節 "① = 有兩套語意：不可變比值，可變比身分")
(對照 "(= @[1 2] @[1 2])"
      "operator== 比內容 → true"
      (string/format "%j —— array 可變，比的是「是不是同一個物件」" (= @[1 2] @[1 2])))
(printf "    對照：(= [1 2] [1 2]) tuple 不可變 => %j" (= [1 2] [1 2]))
(printf "          (deep= @[1 2] @[1 2])       => %j" (deep= @[1 2] @[1 2]))
(print "    心法：可變容器的 = 相當於 C++ 的 &a == &b（比指標）")
(print "    ⚠ 所以 array/table 當不了字典的鍵：")
(printf "          (get (put @{} @[1] :v) @[1]) => %j" (get (put @{} @[1] :v) @[1]))

(節 "② 沒有值語意複製——(def b a) 只是多一個名字")
(def a @[1 2 3])
(def b a)
(array/push b 4)
(對照 "(def b a) 之後 (array/push b 4)"
      "vector<int> b = a; 是深拷貝，a 不受影響"
      (string/format "a 變成 %j —— a 跟 b 是同一份" a))
(print "    要真的拷貝：")
(printf "      (array/slice a)   淺拷貝 array => %j" (array/slice a))
(printf "      (table/clone t)   淺拷貝 table")
(printf "      (thaw (freeze x)) 深拷貝      => %j" (thaw (freeze @{:k @[1]})))
(printf "      (freeze x)        深度轉不可變 => %j" (freeze @{:a @[1 2]}))
(print "    ⚠ 淺拷貝真的只有一層：")
(def 巢 @[@[1]])
(def 淺 (array/slice 巢))
(array/push (get 巢 0) 9)
(printf "      改原本的內層，淺拷貝看到 => %j" (get 淺 0))
(print "    完整說明見 docs/35")

(節 "③ 不寫型別，但型別是真的存在（比 C++ 還嚴格）")
(對照 "(+ 1 \"2\")"
      "C++ 這裡編不過；動態語言通常會幫你轉成 \"12\" 或 3"
      (try (+ 1 "2") ([e] (string "報錯：" e))))
(printf "    字串串接只有這條路：(string \"a\" 1) => %j" (string "a" 1))
(print "    ⚠ int 和 double 在 Janet 都是同一個 :number（IEEE 754 double）：")
(printf "      (type 3) => %j   (type 3.0) => %j   (= 3 3.0) => %j"
        (type 3) (type 3.0) (= 3 3.0))
(對照 "1 << 40"
      "1099511627776（64-bit 左移）"
      (string/format "%j —— 位元運算是 32-bit，位移量被 mod 32（40→8，1<<8=256）"
                     (blshift 1 40)))
(print "    要 64 位元用 int/s64 / int/u64；細節見 docs/21")

(節 "④ 沒有函式重載——同名後定義的直接蓋掉前一個")
(defn dup [x] :第一版)
(defn dup [x] :第二版)
(對照 "連續兩個 (defn dup [x] …)"
      "重載：依參數型別選一個"
      (string/format "(dup 1) => %j —— 第一版消失了，而且不會有警告" (dup 1)))
(print "    想做「同一段邏輯套不同型別」→ 動態型別本來就不挑型別")
(print "    真的需要「產生程式碼」才寫巨集（docs/08）——它改的是語法樹，不是字串")

(節 "⑤ 記憶體是 GC，但資源還是要你收")
(def Conn @{:close (fn [self] (print "      (:close) 被呼叫了"))})
(defn connect [] (table/setproto @{} Conn))
(print "    with 就是你熟悉的 RAII，只是綁在區塊而不是物件生命週期：")
(with [c (connect)] (print "      使用中…"))
(print "    ⚠ body 拋錯時照樣收（這才是 RAII 的重點）：")
(try (with [c (connect)] (error "炸了")) ([e] (printf "      例外照樣往外傳：%s" e)))
(print "    因為有 GC，「物件被回收時」的時機不可預期，所以 Janet 不把資源綁在那上面")
(print "    完整說明見 docs/20b")

(節 "加碼：只有 nil 和 false 為假")
(each v [0 "" @[] nil false]
  (printf "    %-8s → %s" (string/format "%j" v) (if v "真" "假")))
(print "    ⚠ 0 和空字串是真，跟 C++ 相反——這條很常踩")

(節 "心態上最大的差別")
(print "  C++：先設計型別，再讓資料符合型別")
(print "  Janet：資料就是那幾種通用結構，函式直接作用在資料上")
(printf "    三欄的回傳值不必定義 struct，直接回 %j" {:ok true :code 200})
(print "  少了型別檢查的補救：REPL 隨時驗、assert 卡前提、測試寫密一點")

(print "\n✓ cpp-vs-janet 跑完——接著去 docs/02 把四種容器練熟")
