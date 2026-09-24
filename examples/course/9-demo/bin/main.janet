# 配合 course/9-2-jpm-專案.md：執行檔進入點。janet bin/main.janet 或 jpm build 後 ./build/demo
(import ../demo/init :as demo)

(defn main [& args]
  # args 的第 0 個是程式自己，使用者給的參數從第 1 個開始
  (def name (get args 1))
  (print (demo/greet name))
  (printf "1 + 2 = %d" (demo/add 1 2)))
