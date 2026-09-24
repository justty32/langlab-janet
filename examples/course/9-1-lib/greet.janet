# 配合 course/9-1-import-與拆檔.md：被 import 的小模組
(print "（greet.janet 被載入了）")
(def- 招呼語 "你好")
(defn hello [name] (string 招呼語 "，" name))
