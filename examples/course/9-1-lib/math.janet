# 配合 course/9-1-import-與拆檔.md：被 import 的小模組
(defn square [x] (* x x))
(defn- helper [x] (+ x 1))
(defn square+1 [x] (helper (square x)))
