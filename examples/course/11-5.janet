# 配合 course/11-5-接下來去哪.md
# 從 repo 根目錄跑：janet examples/course/11-5.janet

(print "== 接下來去哪 ==")
(def areas
  [["docs/"        "查資料" "某個主題想弄懂細節"     ".md"]
   ["reference/"   "查全"   "這個領域到底有哪些函式" ".md"]
   ["cheatsheets/" "速查"   "忘了寫法、撞到怪行為"   ".md"]
   ["snippets/"    "抄"     "我要做 X，抄哪段"       ".janet"]
   ["exercises/"   "練"     "我到底懂了沒"           ".janet"]])
(each [dir what when] areas
  (printf "%-13s %s：%s" dir what when))

(print "== 數一數每區有幾支檔 ==")
(defn count-files [dir ext]
  (if (os/stat dir)
    (length (filter |(string/has-suffix? ext $) (os/dir dir)))
    nil))

(each [dir _ _ ext] areas
  (def n (count-files dir ext))
  (if n
    (printf "%-13s %d 支 %s" dir n ext)
    (printf "%-13s 找不到（要從 repo 根目錄跑）" dir)))

# ---- 練習解答 ----
# 題目：把 exercises/ 裡的題目檔名照順序印出來，然後在 shell 跑第一份。
(print "== 練習解答 ==")
(if (os/stat "exercises")
  (each name (sort (filter |(string/has-suffix? ".janet" $) (os/dir "exercises")))
    (print "exercises/" name))
  (print "找不到 exercises/（要從 repo 根目錄跑）"))
# os/dir 回來的順序不保證，所以先 sort。跑第一份（在 shell 裡）：
#   janet exercises/01-資料與比較.janet
# 一題都還沒寫時，它會逐題印「✘ 第 N 題」、預期、實得、提示。
# 注意全錯也是 exit 0，要看到「✓ 全部通過」才算過。
