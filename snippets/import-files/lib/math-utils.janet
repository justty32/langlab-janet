# 被引用的模組之一。模組就是一支普通的 .janet 檔——
# 檔案跑完之後，它的 env 就是這個模組。
# 不必寫 export：def/defn 出來的東西預設就是公開的（def- / defn- 才是私有）。

(defn square [x] (* x x))
(defn cube   [x] (* x x x))

(def- 內部常數 42)              # ★ def- 的東西 import 不出去
(defn secret [] 內部常數)        # 但公開函式可以把它露出來

(def VERSION "1.0")
