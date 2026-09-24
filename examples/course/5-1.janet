# 配合 course/5-1-條件.md

(print "== 什麼算真 ==")
(each v [0 "" @[] nil false]
  (printf "%j -> %s" v (if v "yes" "no")))
(printf "(empty? \"\") = %j" (empty? ""))
(printf "(empty? @[]) = %j" (empty? @[]))
(printf "(zero? 0) = %j" (zero? 0))
(printf "(not 0) = %j" (not 0))

(print "== if ==")
(def x (if (even? 4) :even :odd))
(printf "x = %j" x)
(printf "(if (> 3 5) :big) = %j" (if (> 3 5) :big))

(print "== when 與 unless ==")
(def r (when (> 5 3)
         (print "big")
         :done))
(printf "when 回 %j" r)
(printf "when 條件假回 %j" (when (< 5 3) :done))
(printf "unless 回 %j" (unless (nil? 1) :has))

(print "== cond ==")
(defn sign [n]
  (cond
    (< n 0)   :neg
    (zero? n) :zero
    :pos))
(each n [-2 0 9]
  (printf "(sign %d) = %j" n (sign n)))
(printf "沒中也沒 else：%j" (cond false :a))

(print "== case ==")
(defn sound [animal]
  (case animal :dog "woof" :cat "meow" "unknown"))
(printf "%j %j" (sound :cat) (sound :fox))
(printf "沒 else 又沒中：%j" (case :fox :dog "woof"))
(printf "array 比不中：%j" (case @[1 2] @[1 2] :hit :miss))
(printf "tuple 比得中：%j" (case [1 2] [1 2] :hit :miss))

(print "== and 與 or ==")
(printf "(and 1 2 3) = %j" (and 1 2 3))
(printf "(and 1 false 3) = %j" (and 1 false 3))
(printf "(or nil false 7) = %j" (or nil false 7))
(printf "(or nil false) = %j" (or nil false))
(defn greet [&opt name]
  (string "hi, " (or name "guest")))
(printf "%j" (greet "Ann"))
(printf "%j" (greet))
(printf "坑：(or false true) = %j" (or false true))

# ---- 練習解答 ----
(print "== 練習解答 ==")

# 1. grade
(defn grade [score]
  (cond
    (>= score 90) :A
    (>= score 60) :pass
    :fail))
(printf "grade: %j %j %j" (grade 95) (grade 70) (grade 30))

# 2. day-kind
(defn day-kind [d]
  (case d
    :sat "weekend"
    :sun "weekend"
    "weekday"))
(printf "day-kind: %j %j" (day-kind :sun) (day-kind :mon))

# 3. port
(defn port [config]
  (or (get config :port) 8080))
(printf "port: %j %j" (port {:port 3000}) (port {}))
