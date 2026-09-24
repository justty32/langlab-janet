# 配合 course/9-3-寫測試.md：spork/test 版。一條失敗只記一筆，其餘照跑，最後一起結算
(import spork/test :as t)
(import ../demo/init :as demo)

(t/start-suite "demo")
(t/assert (= (demo/add 2 2) 4) "2 + 2 = 4")
(t/assert (= (demo/greet "Ann") "Hello, Ann!") "greet with name")
(t/assert-not (empty? (demo/greet)) "greet is never empty")
(t/assert-error "add needs numbers" (demo/add 1 "x"))
(t/assert-no-error "count-words handles empty string" (demo/count-words ""))
(t/end-suite)
