# default-tools —— 一次組出「預設安全」的整組工具，CLI 與範例都用這個。
#
# 預設有：read-file、list-dir、search-files（限 sandbox 根目錄底下）、now、calc、http-get。
# 沒有的要明講：:write? true 才有 write-file；:shell true 才有 run-command。

(import ./sandbox :as sb)
(import ./tools-fs :as fs)
(import ./tools-search :as search)
(import ./tools-shell :as shell)
(import ./tools-http :as http)
(import ./tools-misc :as misc)

(defn default-tools
  ``組一組工具陣列。

    (default-tools :root ".")                             # 只讀：讀檔、列目錄、搜尋、時間、算數、http-get
    (default-tools :root "/tmp/work" :write? true)        # 多一個 write-file
    (default-tools :root "." :shell true
                   :shell-allow ["ls" "git status"])      # 多一個 run-command，只准這些前綴
    (default-tools :root "." :http? false)                # 拿掉 http-get

  :root 省略＝目前目錄。:shell-timeout／:shell-max-output 原樣轉給 shell-tool。``
  [&named root write? shell shell-allow shell-timeout shell-max-output http?]
  (default root ".")
  (default http? true)
  (def sandbox (sb/make-sandbox root :write? write?))
  (def out (fs/fs-tools sandbox))
  (array/push out (search/search-files-tool sandbox))
  (array/push out misc/now-tool)
  (array/push out misc/calc-tool)
  (when http? (array/push out (http/http-get-tool)))
  (when shell
    (array/push out (shell/shell-tool :allow shell-allow
                                      :timeout shell-timeout
                                      :max-output shell-max-output)))
  out)
