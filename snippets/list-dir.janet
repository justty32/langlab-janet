#!/usr/bin/env janet
# 列出一個資料夾底下所有 entry（可選遞迴），並標出種類。
# 跑法：janet snippets/list-dir.janet [路徑] [-r]
#
# 重點：
#   * (os/dir path) 回傳的是「名字」不是完整路徑，要自己接前綴
#   * 它不含 "." 和 ".."
#   * 路徑不是資料夾 / 不存在 → 會 error（不是回 nil），用 protect 或先 os/stat
#   * 遞迴要自己寫；spork/path 幫你處理路徑拼接與分隔符

(import spork/path)

(defn safe-dir
  "列一個資料夾，失敗時回 nil 而不是丟例外。"
  [dir]
  (def [ok res] (protect (os/dir dir)))
  (if ok res nil))

(defn entries
  "回傳 @[{:name … :path … :mode …} …]，依名字排序。"
  [dir]
  (def names (or (safe-dir dir) @[]))
  (seq [n :in (sort names)]
    (def full (path/join dir n))
    @{:name n
      :path full
      :mode (or (os/lstat full :mode) :未知)     # lstat：symlink 不跟隨
      :size (or (os/lstat full :size) 0)}))

(defn- mark [mode]
  (case mode
    :directory "/"
    :link      "@"
    :fifo      "|"
    :socket    "="
    ""))

(defn print-dir
  "印一層。recur 為真就遞迴進子資料夾（用縮排表示層次）。"
  [dir &opt recur depth]
  (default depth 0)
  (def pad (string/repeat "  " depth))
  (each e (entries dir)
    (printf "%s%s%s   %s" pad (e :name) (mark (e :mode)) (string (e :mode)))
    (when (and recur (= :directory (e :mode)))
      (print-dir (e :path) recur (inc depth)))))

(defn walk
  "另一種寫法：把所有檔案的完整路徑攤平成一個陣列（不含資料夾本身）。"
  [dir]
  (def out @[])
  (defn go [d]
    (each e (entries d)
      (if (= :directory (e :mode))
        (go (e :path))
        (array/push out (e :path)))))
  (go dir)
  out)

(defn main [& args]
  (def dir   (or (get args 1) "."))   # ★ get 才安全，(args 1) 越界會報錯
  (def recur (some |(= $ "-r") (slice args 1)))
  (unless (= :directory (os/stat dir :mode))
    (printf "%s 不是資料夾（或不存在）" dir)
    (os/exit 1))
  (printf "── %s%s" dir (if recur "（遞迴）" ""))
  (print-dir dir recur)
  (printf "\n攤平成路徑清單，共 %d 個檔案" (length (walk dir))))
