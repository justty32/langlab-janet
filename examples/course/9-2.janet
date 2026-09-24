# 配合 course/9-2-jpm-專案.md：main 自動呼叫、args 第 0 個是程式自己、頂層先跑
(print "== 頂層程式碼 ==")
(print "載入這支檔就會印這行（被 import 也會）")

(defn main [& args]
  (print "== main ==")
  (printf "main 收到 %d 個參數：%j" (length args) args)
  (printf "第 0 個是程式自己：%s" (get args 0))
  (printf "使用者給的：%j" (tuple/slice args 1)))

# ---- 練習解答 ----
# 練習 1：main 裡印出使用者給的參數個數（不含程式自己）：
#   (print (- (length args) 1))
# 練習 2：在 project.janet 加一條「編完就跑」的 rule：
#   (phony "go" ["build"] (os/execute ["./build/demo" "Ann"] :p))
#   然後 jpm run go
# 練習 3：改了 demo/init.janet 卻 jpm build 沒反應，要 jpm clean && jpm build
