# 配合 course/9-3-寫測試.md：內建 assert 與 spork/test 兩套寫法
(import spork/test :as t)
(import ./9-demo/demo/init :as demo)

(print "== assert 回傳被檢查的值 ==")
(print (assert 5 "x"))                        # 5，不是 true
(def total (assert (demo/add 1 2) "add 壞了"))  # 檢查完直接拿來用
(print total)

(print "== 失敗訊息長怎樣 ==")
(pp (protect (assert (= 1 2))))                   # 沒給訊息
(pp (protect (assert (= 1 2) "month should be 0-based")))
(pp (protect (assertf (= 1 2) "want %d got %d" 1 2)))
(print (get (protect (assert false "中文訊息照常顯示")) 1))

(print "== deep= 與 = ==")
(print (= @[1 2] @[1 2]))       # false：兩個不同的 array
(print (deep= @[1 2] @[1 2]))   # true：比內容
(print (= [1 2] [1 2]))         # true：tuple 本來就比內容

(print "== 該失敗：用 protect ==")
(defn parse-port [s]
  (or (scan-number s) (error "port is not a number")))
(def [ok e] (protect (parse-port "abc")))
(assert (not ok) "壞輸入應該要丟錯")
(assert (= e "port is not a number") "錯誤訊息要對")
(print "ok = " ok ", e = " e)
(pp (protect (/ 1 0)))          # 不會爆，回 inf
(pp (protect (get nil :a)))     # 不會爆，回 nil

(print "== 浮點數比差值 ==")
(print (= (+ 0.1 0.2) 0.3))
(print (< (math/abs (- (+ 0.1 0.2) 0.3)) 1e-9))

(print "== spork/test 的 suite ==")
(t/start-suite "course-9-3")
(t/assert (= (demo/add 2 2) 4) "add")
(t/assert-not (empty? (demo/greet)) "greet never empty")
(t/assert-error "add needs numbers" (demo/add 1 "x"))
(t/assert-no-error "count-words on empty string" (demo/count-words ""))
(t/end-suite)   # 全過才不會 exit；有失敗會讓行程 exit 1

(print "== capture-stdout ==")
(def [ret out] (t/capture-stdout (print "hi") 42))
(printf "ret = %j, out = %j" ret out)

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. count-words 的兩條內建 assert
(assert (= (demo/count-words "") 0) "空字串是 0 個字")
(assert (= (demo/count-words "a b c") 3) "三個字")
# 2. 「add 給字串該失敗」的測試（先確認它真的會爆）
(def [ok2 e2] (protect (demo/add 1 "x")))
(assert (not ok2) "add 給字串應該要丟錯")
(print "練習 2 抓到的錯誤：" e2)
# 3. 用 capture-stdout 測一個會 print 的函式
(defn say-hi [name] (print (demo/greet name)) :done)
(def [r3 o3] (t/capture-stdout (say-hi "Ann")))
(assert (= r3 :done) "回傳值在前")
(assert (= o3 "Hello, Ann!\n") "印出的東西在後")
(print "練習全部通過")
