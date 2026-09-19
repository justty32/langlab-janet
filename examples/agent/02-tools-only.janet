# agent 範例 ② —— 工具箱本身不需要打模型：sandbox、calc、search-files 直接叫得動。
#
# 用來搞懂「工具」跟「agent loop」是分開的兩件事——loop 只是照模型的要求呼叫這些函式。
# 完全離線，不需要任何後端。
#
# 跑法：janet examples/agent/02-tools-only.janet

(import ../../modules/agent/init :as ag)

(defn main [&]
  (def sb (ag/make-sandbox "."))
  (printf "sandbox root = %s" (sb :root))
  (printf "可寫？ = %s\n" (string (sb :write?)))

  # 工具是普通的 table：:name :description :parameters :handler
  (def tools (ag/default-tools :root "."))
  (printf "預設工具：%s\n" (string/join (ag/tool-names tools) "、"))

  # call-tool：照名字執行，回傳一定是字串（handler 丟例外也接住，回錯誤字串）
  (print "── calc ──")
  (print (ag/call-tool tools "calc" @{:expression "(12+3)*4"}))

  (print "\n── list-dir（project.janet 所在目錄）──")
  (print (ag/call-tool tools "list-dir" @{:path "modules/agent"}))

  (print "\n── 越界會被 sandbox 擋下，回錯誤字串而不是丟例外 ──")
  (print (ag/call-tool tools "read-file" @{:path "../../etc/passwd"}))

  (print "\n── search-files：純文字比對，不是 regex ──")
  (each hit (ag/search-files sb "make-sandbox" :dir "modules/agent" :max-hits 3)
    (print hit)))
