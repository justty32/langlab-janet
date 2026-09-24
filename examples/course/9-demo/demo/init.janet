# 配合 course/9-2-jpm-專案.md：專案的核心模組，只放純函式，別人 import 這支
(defn add
  "兩數相加。"
  [a b]
  (+ a b))

(defn greet
  "組一句問候。沒給名字就用 world。"
  [&opt name]
  (string "Hello, " (or name "world") "!"))

(defn count-words
  "算一句話有幾個字（用空白切）。"
  [s]
  (length (filter |(not (empty? $)) (string/split " " s))))
