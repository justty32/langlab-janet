# 配合 docs/37-什麼操作貴.md
#
#   janet examples/bench.janet
#
# ⚠ 這支檔的重點不是「印出漂亮的數字」，是讓你在**自己的機器上**重跑一遍。
#   文件裡的絕對毫秒數換台機器就變，有意義的只有倍數與排序。
#   全部跑完約 2～4 秒。

(defn 計時
  "跑 f 一次並回傳耗時（秒）。⚠ 一定用 :monotonic，理由見 docs/24。"
  [f]
  (def t0 (os/clock :monotonic))
  (f)
  (- (os/clock :monotonic) t0))

(defn 比 [說明 &named 慢 快 慢名 快名]
  (快)                                    # 暖身：讓兩邊都先跑過一次
  (慢)
  (def t慢 (計時 慢))
  (def t快 (計時 快))
  (print "\n── " 說明 " ─────────────────────")
  (printf "  %-32s %8.1f ms" 慢名 (* 1000 t慢))
  (printf "  %-32s %8.1f ms" 快名 (* 1000 t快))
  (printf "  → 快 %.0f 倍" (/ t慢 t快)))

(defn 列 [說明 f &opt 次]
  (default 次 1)
  (f)
  (printf "  %-34s %8.1f ms" 說明 (* 1000 (計時 f))))

(def N 20000)

(比 (string "在迴圈裡累積字串（" N " 次）")
    :慢名 "(set s (string s \"x\"))"   :慢 (fn [] (var s "") (for i 0 N (set s (string s "x"))))
    :快名 "(buffer/push-string b \"x\")" :快 (fn [] (def b @"") (for i 0 N (buffer/push-string b "x"))))
(print "  string 每次造新字串並整個抄過去 → O(N²)；buffer 往後接 → O(N)")

(比 (string "在迴圈裡累積元素（" N " 次）")
    :慢名 "每圈造一個新 array"  :慢 (fn [] (var a @[]) (for i 0 N (set a (array/concat @[] a i))))
    :快名 "(array/push a i)"    :快 (fn [] (def a @[]) (for i 0 N (array/push a i))))
(print "  一句話：迴圈裡不要造新容器，往可變容器裡塞。這是第一名的效能問題")

(def M 300000)
(def arr (seq [i :range [0 1000]] i))
(def tbl (tabseq [i :range [0 1000]] i i))
(def st  (freeze tbl))
(print "\n── 查一個元素（" M " 次）—— 三者差不多，別為此糾結 ─────────")
(列 "(arr 500)   array 索引" (fn [] (var s 0) (for i 0 M (set s (arr 500)))))
(列 "(st 500)    struct 查鍵" (fn [] (var s 0) (for i 0 M (set s (st 500)))))
(列 "(tbl 500)   table 查鍵" (fn [] (var s 0) (for i 0 M (set s (tbl 500)))))
(列 "(get-in d [:a :b]) 兩層" (fn [] (def d {:a {:b 1}}) (var s 0) (for i 0 M (set s (get-in d [:a :b])))))
(print "  ⚠ 只有 get-in 明顯慢——它要走一遍路徑清單。熱迴圈裡先把中間層取出來存著")

(print "\n── 走訪 1000 個元素 300 次 —— 完全一樣，照可讀性選 ─────────")
(列 "(map inc arr)"             (fn [] (for i 0 300 (map inc arr))))
(列 "(seq [x :in arr] (inc x))" (fn [] (for i 0 300 (seq [x :in arr] (inc x)))))
(列 "each + array/push"         (fn [] (for i 0 300 (do (def o @[]) (each x arr (array/push o (inc x)))))))

(print "\n── ★ 不可變字面值是免費的（" M " 次）─────────")
(列 "[1 2 3]   常值 tuple"  (fn [] (for i 0 M [1 2 3])))
(列 "@[1 2 3]  常值 array"  (fn [] (for i 0 M @[1 2 3])))
(列 "[i i i]   要算的 tuple" (fn [] (for i 0 M [i i i])))
(列 "@[i i i]  要算的 array" (fn [] (for i 0 M @[i i i])))
(print "  這不是「tuple 比 array 快」——反組譯就看得出真正的原因：")

(each [說明 f] [["(fn [] [1 2 3])"  (fn [] [1 2 3])]
                ["(fn [] @[1 2 3])" (fn [] @[1 2 3])]
                ["(fn [] {:a 1})"   (fn [] {:a 1})]
                ["(fn [] @{:a 1})"  (fn [] @{:a 1})]]
  (def d (disasm f))
  (printf "    %-18s constants=%j" 說明 (d :constants))
  (printf "    %-18s bytecode =%j" "" (d :bytecode)))

(print "\n  ldc  = load constant → 編譯期就固定成一個常數，每次都是同一個")
(print "  mkarr/mktab = 每次真的建一個新的")
(print "  所以內容固定的對照表用 {} / [] 寫是真的零成本，用 @{} / @[] 寫則每次重建")
(print "  ⚠ 但內容要算的時候兩者一樣貴，別為此改用 tuple")

(print "\n✓ bench 跑完——記得看倍數，不要記絕對毫秒數")
