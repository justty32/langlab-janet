# search-files —— grep 式的搜尋：在 sandbox 底下遞迴找「哪些檔的哪一行含這段文字」。
#
# 刻意做得保守：
#   * 純文字比對（string/find），不是 regex——模型給的 pattern 不會被當成語法解釋
#   * 跳過 .git 與任何以 . 開頭的資料夾、跳過 symlink、跳過超過 :max-file-bytes 的檔、跳過含 NUL 的二進位檔
#   * 最多回 :max-hits 行，超過就註明；一行太長也截斷
# 回給模型的是「相對路徑:行號: 那一行」，跟 grep -n 一樣的形狀。

(import spork/path)
(import ./registry :as reg)
(import ./sandbox :as sb)

(def search-max-hits 50)
(def search-max-file-bytes 1000000)
(def search-line-limit 200)

(defn- skip-dir? [name]
  (string/has-prefix? "." name))

(defn- binary? [content]
  (truthy? (string/find "\0" content)))

(defn- clip [line]
  (if (> (length line) search-line-limit)
    (string (string/slice line 0 search-line-limit) "…")
    line))

(defn- scan-file
  "把一個檔裡含 pattern 的行推進 hits；回傳有沒有撞到上限。"
  [sandbox real pattern hits max-hits max-file-bytes]
  (def st (os/stat real))
  (when (and st (= :file (st :mode)) (<= (st :size) max-file-bytes))
    (def content (string (slurp real)))
    (unless (binary? content)
      (def rel (sb/display-path sandbox real))
      (var lineno 0)
      (each line (string/split "\n" content)
        (++ lineno)
        (when (and (< (length hits) max-hits) (string/find pattern line))
          (array/push hits (string rel ":" lineno ": " (clip line)))))))
  (>= (length hits) max-hits))

(defn- walk
  "深度優先走資料夾；hits 滿了就提早停。"
  [sandbox dir pattern hits max-hits max-file-bytes]
  (var full false)
  (each name (sorted (os/dir dir))
    (unless full
      (def child (path/join dir name))
      # ⚠ 用 os/lstat 不用 os/stat：symlink 一律跳過，不然 root 裡一個指到 / 的連結就會把整台機器走一遍
      (def mode (os/lstat child :mode))
      (cond
        (= mode :directory)
        (unless (skip-dir? name)
          (set full (walk sandbox child pattern hits max-hits max-file-bytes)))
        (= mode :file)
        (set full (scan-file sandbox child pattern hits max-hits max-file-bytes)))))
  full)

(defn search-files
  ``純函式版：在 sandbox 的 dir（相對路徑，省略＝root）底下找含 pattern 的行，回字串陣列。
  給測試與 CLI 直接用；search-files-tool 只是把它包成工具。``
  [sandbox pattern &named dir max-hits max-file-bytes]
  (default dir ".")
  (default max-hits search-max-hits)
  (default max-file-bytes search-max-file-bytes)
  (when (or (nil? pattern) (empty? pattern)) (error "pattern 是空的"))
  (def real (sb/resolve-existing sandbox dir))
  (def hits @[])
  (case (os/stat real :mode)
    :directory (walk sandbox real pattern hits max-hits max-file-bytes)
    :file      (scan-file sandbox real pattern hits max-hits max-file-bytes)
    (error (string dir " 既不是檔案也不是資料夾")))
  hits)

(defn search-files-tool
  "search-files：包成工具。撞到 :max-hits 會在最後加一行提醒模型縮小範圍。"
  [sandbox &named max-hits max-file-bytes]
  (default max-hits search-max-hits)
  (reg/make-tool "search-files"
    "在工作目錄底下遞迴搜尋含某段文字的行（純文字比對，不是 regex）。回「路徑:行號: 內容」。"
    {:type "object"
     :properties {:pattern {:type "string" :description "要找的文字"}
                  :path    {:type "string" :description "只在這個子資料夾找；省略＝整個工作目錄"}}
     :required ["pattern"]}
    (fn [args]
      (def hits (search-files sandbox (get args :pattern)
                              :dir (get args :path ".")
                              :max-hits max-hits :max-file-bytes max-file-bytes))
      (cond
        (empty? hits) "（沒有找到）"
        (>= (length hits) max-hits)
        (string (string/join hits "\n") "\n…（只列前 " max-hits " 筆，請縮小範圍）")
        (string/join hits "\n")))))
