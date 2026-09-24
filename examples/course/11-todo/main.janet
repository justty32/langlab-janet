# 配合 course/11-1-todo-規劃與骨架.md：todo 的進入點，只做一件事：把參數交給指令層。
# 跑法：janet main.janet <add|list|done|rm> [參數] [--file 路徑]
(import ./todo/cli)

(defn main [& argv]
  # argv[0] 是程式自己的名字，從 [1] 起才是使用者打的
  (os/exit (cli/run (array/slice argv 1))))
