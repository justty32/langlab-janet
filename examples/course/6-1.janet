# 配合 course/6-1-函式與參數.md（與續篇 6-1b）

(print "== 最基本的 defn ==")
(defn 平方 [x] (* x x))
(print (平方 7))                      # 49
(defn 矩形面積 [寬 高] (* 寬 高))
(print (矩形面積 3 4))                # 12

(print "== 可以省略的參數 &opt ==")
(defn 打招呼 [名字 &opt 稱呼]
  (if 稱呼
    (string "你好，" 名字 " " 稱呼)
    (string "你好，" 名字)))
(print (打招呼 "小明"))
(print (打招呼 "小明" "老師"))
(defn a [x &opt y] [x y])
(pp (a 1))                            # (1 nil)
(pp (a 1 2))                          # (1 2)

(print "== 預設值要用 default ==")
(defn 等待 [工作 &opt 秒數]
  (default 秒數 30)
  [工作 秒數])
(pp (等待 :download))                 # (:download 30)
(pp (等待 :download 5))               # (:download 5)

(print "== 收不定個數的 & ==")
(defn 加總 [& 數字] (reduce + 0 數字))
(print (加總 1 2 3))                  # 6
(print (加總))                        # 0
(defn c [x & 其餘] [x 其餘])
(pp (c 1 2 3))                        # (1 (2 3))
(pp (c 1))                            # (1 ())

(print "== 用名字指定的 &named ==")
(defn 連線 [主機 &named port timeout] [主機 port timeout])
(pp (連線 "example.com" :port 80))
(pp (連線 "example.com" :timeout 5 :port 443))
(pp (連線 "example.com"))
(defn 轉手 [x &keys 其他] [x 其他])
(pp (轉手 1 :port 80 :host "h"))      # (1 {:host "h" :port 80})

(print "== docstring ==")
(defn 加一 "把數字加一。" [x] (+ x 1))
(doc 加一)
(defn- 內部用 [] :x)                  # 只在這支檔裡用，import 不會帶出去
(print (內部用))

(print "== 坑：default 補的是 nil ==")
(pp (等待 :download nil))             # (:download 30)，明確傳 nil 也被補

(print "== 坑：引數個數 ==")
# (a) 這樣寫是編譯期錯誤，整支檔跑到這裡就停，所以這裡不放。
# 用 apply 把引數攤開，個數要到執行時才知道，這時 protect 才接得住。
(pp (protect (apply a [])))
(pp (protect (apply a [1 2 3])))

# ---- 練習解答 ----
(print "== 練習解答 ==")

# 1. 問候：語言沒給就當 :zh
(defn 問候 [名字 &opt 語言]
  (default 語言 :zh)
  (case 語言
    :zh (string "你好，" 名字)
    :en (string "Hello, " 名字)))
(print (問候 "小明"))                 # 你好，小明
(print (問候 "Ming" :en))             # Hello, Ming

# 2. 最大：至少一個數字，其餘不定個
(defn 最大 [第一個 & 其餘]
  (apply max 第一個 其餘))
(print (最大 3))                      # 3
(print (最大 3 9 4))                  # 9

# 3. 做便當：兩個具名參數各有預設值
(defn 做便當 [主菜 &named 飯量 辣度]
  (default 飯量 :normal)
  (default 辣度 0)
  {:main 主菜 :rice 飯量 :spicy 辣度})
(pp (做便當 :chicken))                # {:main :chicken :rice :normal :spicy 0}
(pp (做便當 :beef :辣度 2 :飯量 :large))
