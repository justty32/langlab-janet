# 配合 course/9-3-寫測試.md：內建 assert 版。正常跑完就是通過，中途丟錯就是失敗
(import ../demo/init :as demo)

(assert (= (demo/add 1 2) 3) "1 + 2 應該是 3")
(assert (= (demo/greet) "Hello, world!") "沒給名字要用 world")
(assert (= (demo/greet "Janet") "Hello, Janet!") "有給名字要用名字")
(assert (= (demo/count-words "a b  c") 3) "連續空白不算一個字")

(print "basic 測試通過")
