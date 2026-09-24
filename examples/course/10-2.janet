# 配合 course/10-2-ev-非同步.md
(defn show [x] (print (string/format "%j" x)))

(print "== spawn 與 sleep ==")
(ev/spawn (print "背景 A"))
(ev/spawn (print "背景 B"))
(print "主線先印")
(ev/sleep 0)
(print "主線 sleep 完")

(ev/spawn (for i 0 3 (print "慢 " i) (ev/sleep 0.02)))
(ev/spawn (for i 0 3 (print "快 " i) (ev/sleep 0.01)))
(ev/sleep 0.1)

(print "== channel 傳值 ==")
(def ch (ev/chan))
(ev/spawn (ev/sleep 0.02) (ev/give ch "worker done"))
(print "主線等結果")
(show (ev/take ch))

(def results (ev/chan 10))
(for i 0 3 (ev/spawn (ev/sleep (* 0.01 (- 3 i))) (ev/give results i)))
(show (seq [_ :range [0 3]] (ev/take results)))

(show (ev/gather (do (ev/sleep 0.02) :a) (do (ev/sleep 0.01) :b)))

(print "== 逾時與取消 ==")
(show (protect (ev/with-deadline 0.02 (ev/sleep 10))))
(def task (ev/go (fn [] (try (forever (ev/sleep 0.01)) ([e] (print "被取消了：" e))))))
(ev/sleep 0.03)
(ev/cancel task "夠了")
(ev/sleep 0.03)

(print "== 坑：忙迴圈要放 sleep 0 ==")
(ev/spawn (print "背景有機會了"))
(var n 0)
(while (< n 3) (++ n) (ev/sleep 0))
(print "主線迴圈結束")

(print "== 坑：chan-close 會丟掉剩下的東西 ==")
(def c2 (ev/chan 10))
(ev/give c2 :a)
(ev/give c2 :b)
(show (ev/count c2))
(ev/chan-close c2)
(show (ev/take c2))
# 正確做法：送結束值
(def c3 (ev/chan 10))
(ev/spawn (for i 0 3 (ev/give c3 (* i 10))) (ev/give c3 :done))
(loop [v :iterate (ev/take c3) :until (= v :done)] (print "收到 " v))

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. 三個工人，印到達順序
(def order (ev/chan 10))
(each [id secs] [[1 0.03] [2 0.01] [3 0.02]]
  (ev/spawn (ev/sleep secs) (ev/give order id)))
(show (seq [_ :range [0 3]] (ev/take order)))
# 2. 逾時接住
(try (ev/with-deadline 0.05 (ev/sleep 1) (print "不會印到這"))
  ([e] (print "逾時了：" e)))
