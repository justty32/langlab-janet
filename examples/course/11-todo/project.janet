# 配合 course/11-1-todo-規劃與骨架.md ～ 11-4-todo-測試與打包.md
# todo：一個真的能用的待辦命令列工具（add／list／done／rm，資料存 JSON 檔）。
#
#   janet main.janet add 買牛奶      # 開發時直接跑
#   jpm test                        # 跑 test/ 底下全部測試
#   jpm build && ./build/todo list  # 編成單一執行檔再跑（跑完 jpm clean 清掉）

(declare-project
  :name "todo"
  :description "課程用的待辦命令列工具"
  :version "0.1.0"
  :dependencies ["spork"])

# 給別人 import 用的原始碼（jpm install 才會用到；build 不需要它）
(declare-source
  :prefix "todo"
  :source ["todo/store.janet" "todo/cli.janet"])

# jpm build 會照這個編出 build/todo
(declare-executable
  :name "todo"
  :entry "main.janet"
  :install false)
