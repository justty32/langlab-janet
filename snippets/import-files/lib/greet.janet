# 模組可以再 import 別的模組；路徑是相對「這支檔案自己」的位置。
(import ./math-utils :as m)

(defn hello [who] (string "Hello, " who "!"))
(defn 平方問候 [n] (string "n² = " (m/square n)))
