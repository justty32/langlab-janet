# 配合 docs/22-原型與方法.md
#
#   janet examples/prototypes.janet
#
# Janet 版的「類別」：方法呼叫語法 ＋ 原型鏈，以及三個一定會踩的地方。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-34s => %j" 說明 結果))

(節 "方法呼叫語法不是特殊機制，只是 keyword 可以當函式用")
(def t @{:greet (fn [self] (string "hi, " (self :name))) :name "Al"})
(秀 "(:greet t)" (:greet t))
(秀 "((get t :greet) t)  ← 完全等價" ((get t :greet) t))
(print "  self 沒有魔法，就是第一個參數，叫 this 也行")

(節 "原型鏈：「類別」就是一個放方法的 table")
(def Point
  @{:norm (fn [self] (math/sqrt (+ (* (self :x) (self :x))
                                   (* (self :y) (self :y)))))
    :show (fn [self] (string "(" (self :x) "," (self :y) ")"))})

(defn point [x y] (table/setproto @{:x x :y y} Point))   # 「建構子」就是普通函式

(def p (point 3 4))
(秀 "(:norm p)" (:norm p))
(秀 "(:show p)" (:show p))
(print "  對照 C++：instance 只放資料，prototype 那個 table 就是 vtable ＋ 靜態成員")
(print "  每個 instance 只多一個指向 prototype 的指標，方法不會被複製")

(節 "繼承就是「原型再掛原型」")
(def Point3 (table/setproto @{:show (fn [self] "3d point")} Point))
(def q (table/setproto @{:x 1 :y 2 :z 3} Point3))
(秀 "(:show q)  Point3 蓋掉 Point 的" (:show q))
(秀 "(:norm q)  沒定義就往上找到 Point" (:norm q))
(print "  查找順序：q → Point3 → Point，先找到先贏")
(秀 "沒有 super，自己往上取父類版本"
    ((get (table/getproto Point3) :show) q))

(節 "⚠ 陷阱①：get 會走原型鏈，keys / length 不會")
(秀 "(function? (get p :norm))  找得到" (function? (get p :norm)))
(秀 "(keys p)                   看不到 :norm" (keys p))
(秀 "(length p)                 只算自己的" (length p))
(print "  好處：序列化成 JSON 時方法自動不會被帶進去")
(print "  代價：想列舉「這物件有哪些能力」得自己往 table/getproto 上爬")

(節 "⚠ 陷阱②：prototype 是共用的，改它會影響已經建好的 instance")
(def p2 (point 6 8))
(秀 "改之前 (:show p2)" (:show p2))
(put Point :show (fn [self] "prototype 被改掉了"))
(秀 "改之後 (:show p2)  ← p2 早就建好了" (:show p2))
(print "  這是特性不是 bug——等於 runtime patch vtable")

(print "\n  但它意味著：別把可變的預設值放進 prototype")
(def 壞 @{:items @[]})                                   # ⚠ 所有 instance 共用同一個 array
(def a1 (table/setproto @{} 壞))
(def a2 (table/setproto @{} 壞))
(array/push (a1 :items) :a1塞的)
(秀 "a1 塞完，a2 看到的 :items" (a2 :items))
(print "    ↑ a2 什麼都沒做卻看得到——兩個共用同一個 array")

(def 好 @{:init (fn [self] (put self :items @[]) self)}) # 建構時各給各的
(def b1 (:init (table/setproto @{} 好)))
(def b2 (:init (table/setproto @{} 好)))
(array/push (b1 :items) :b1塞的)
(秀 "改成建構時才給，b2 看到的" (b2 :items))
(print "  跟 Python class attribute 的經典陷阱一樣；C++ 那邊像誤把成員宣告成 static")

(節 "⚠ 陷阱③：struct 也能有 prototype，但印不出來")
(def s (struct/with-proto {:b 2} :a 1))
(秀 "s 印出來" s)
(秀 "(s :b)  但查得到" (s :b))
(print "  實務上很少用；要做物件請用 table")

(節 "最實用的：物件有 :close 就能配合 with（＝RAII）")
(def Conn @{:close (fn [self] (print "    斷線"))
            :query (fn [self q] (print "    查詢 " q))})
(defn connect [] (table/setproto @{:host "x"} Conn))

(print "  正常結束：")
(with [c (connect)] (:query c "select 1"))

(print "\n  ⚠ body 拋錯時 :close 照樣會被呼叫——這才是它等同 RAII 的地方：")
(try (with [c (connect)] (error "炸了"))
     ([e] (printf "    例外照樣往外傳，接到：%s" e)))

(print "\n✓ prototypes 跑完")
