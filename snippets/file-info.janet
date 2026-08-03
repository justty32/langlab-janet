#!/usr/bin/env janet
# 查一個路徑的資訊：存不存在、是檔案還是資料夾、可不可執行、上次修改時間…
# 跑法：janet snippets/file-info.janet [路徑...]（不給就查幾個預設路徑）
#
# 重點：
#   * (os/stat path)      → table；路徑不存在回 nil（不是報錯）
#   * (os/stat path :key) → 只取一個欄位，省得建整張表
#   * os/stat 會「跟隨」symlink；要看 symlink 本身用 os/lstat
#   * :mode 是 keyword：:file :directory :link :fifo :socket :block :character :other
#   * 時間欄位是 Unix 秒數，丟給 (os/date t) 轉成人看的樣子

(defn- fmt-time [t]
  (def d (os/date t))
  (string/format "%04d-%02d-%02d %02d:%02d:%02d"
                 (d :year) (inc (d :month)) (inc (d :month-day))
                 (d :hours) (d :minutes) (d :seconds)))

(defn- fmt-size [n]
  (cond
    (< n 1024)         (string n " B")
    (< n (* 1024 1024)) (string/format "%.1f KiB" (/ n 1024))
    (string/format "%.1f MiB" (/ n 1024 1024))))

(defn executable?
  "有沒有任何一個 x 位元。注意這是「檔案標記為可執行」，不等於「我有權跑」
  （那還要看 uid/gid）。要真的確定，直接跑跑看接 (protect ...) 比較實在。"
  [st]
  (not (zero? (band (st :int-permissions) 8r111))))

(defn describe
  "回傳一張好讀的描述表；路徑不存在回 nil。"
  [path]
  (def st (os/stat path))
  (if (nil? st)
    nil
    @{:路徑     path
      :種類     (st :mode)                       # :file / :directory / :link …
      :是資料夾 (= :directory (st :mode))
      :是檔案   (= :file (st :mode))
      :可執行   (executable? st)
      :權限     (st :permissions)                # "rwxr-xr-x"
      :大小     (fmt-size (st :size))
      :修改時間 (fmt-time (st :modified))
      :存取時間 (fmt-time (st :accessed))
      :inode    (st :inode)}))

(defn symlink?
  "os/stat 會跟隨 symlink，所以要問「這個路徑本身是不是 symlink」得用 os/lstat。"
  [path]
  (= :link (os/lstat path :mode)))

(defn main [& args]
  (def paths (if (> (length args) 1)
               (slice args 1)
               ["/etc/passwd" "/tmp" "/bin/sh" "/no/such/path"]))
  (each p paths
    (print "── " p)
    (def info (describe p))
    (if (nil? info)
      (print "   （不存在）")
      (do
        (each k [:種類 :是資料夾 :是檔案 :可執行 :權限 :大小 :修改時間 :存取時間]
          (printf "   %s：%s" (string k) (string (info k))))
        (when (symlink? p)
          (printf "   是連結：→ %s（os/stat 會跟隨它，os/lstat 才看得到）"
                  (os/readlink p)))))
    (print)))
