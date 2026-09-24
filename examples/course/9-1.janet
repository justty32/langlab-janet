# 配合 course/9-1-import-與拆檔.md
# 跑法：janet examples/course/9-1.janet（在哪個目錄下指令都可以）

(print "== 基本 import ==")
(import ./9-1-lib/greet)            # 前綴取路徑最後一段 → greet/
(print (greet/hello "小明"))

(print "== :as 與 :prefix ==")
(import ./9-1-lib/math :as m)       # 自己取前綴 → m/
(print (m/square 5))
(import ./9-1-lib/math :prefix "")  # 不加前綴
(print (square 6))

(print "== 相對路徑相對這支檔 ==")
(print "這支檔：" (dyn :current-file))
(each k (sort (map string (keys module/cache)))
  (when (string/find "9-1-lib" k) (print "已載入：" k)))

(print "== 裸名字走系統模組路徑 ==")
(import spork/path)
(print "syspath：" (dyn :syspath))
(print (path/join "a" "b"))
(def r (protect (eval-string "(import greet)")))
(print (first (string/split "\n" (r 1))))

(print "== 不帶 .janet ==")
(import ./9-1-lib/greet)            # 慣例寫法，Janet 自己去找 greet.janet
(print "greet 已經在快取裡，這行不會再印「被載入了」")

(print "== import 要放頂層 ==")
(def r2 (protect (eval-string ``(defn show []
  (import ./9-1-lib/greet :as gg)
  (gg/hello "x"))``)))
(print (r2 1))

(print "== ~ 不是家目錄 ==")
(printf "%q 的型別是 %q" '~/repo/x (type '~/repo/x))
(def r3 (protect (eval-string "(import ~/repo/x)")))
(print (first (string/split "\n" (r3 1))))

(print "== 載入一次、私有的拿不到 ==")
(print "m/square 就是 square：" (= m/square square))
(printf "私有的 helper 進不來：%q" (get (curenv) (quote helper)))
(print "但公開的 square+1 可以用它：" (square+1 3))

(print "== use ==")
(use ./9-1-lib/greet)               # 不加前綴，全部倒進來
(print (hello "阿華"))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 用 :as mt 載入 math，算 12 的平方
(import ./9-1-lib/math :as mt)
(print "1. " (mt/square 12))
# 2. 想拿家目錄的檔，~ 不行；路徑要用字串自己組，再交給 dofile
#    (dofile (string (os/getenv "HOME") "/repo/x.janet"))
(print "2. " (string (os/getenv "HOME") "/repo/x.janet"))
# 3. 從 /tmp 跑 janet 絕對路徑/9-1.janet 一樣找得到 greet，
#    因為 ./9-1-lib 相對的是 9-1.janet 所在的目錄，不是 /tmp
(print "3. 找得到")
