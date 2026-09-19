# 檔案工具 —— read-file／list-dir／write-file，全部先經過 sandbox 再碰檔案。
#
# 每個工具都是「給一個 sandbox → 回一張工具 table」的函式，這樣同一支程式可以
# 對不同根目錄各開一組。write-file 只有在 sandbox 開了 :write? 才會被 fs-tools 放進去。
# 回給模型的路徑一律是相對 root 的（display-path），不洩漏本機絕對路徑。

(import spork/path)
(import ./registry :as reg)
(import ./sandbox :as sb)

(def read-max-bytes
  "read-file 一次最多回多少 bytes；超過就截斷並註明，免得一個大檔塞爆 context。"
  20000)

(defn- truncate
  "超過 n bytes 就砍掉尾巴並加一行說明。"
  [s n]
  (if (<= (length s) n)
    s
    (string (string/slice s 0 n) "\n…（已截斷，原檔共 " (length s) " bytes）")))

(defn read-file-tool
  "read-file：讀 root 底下的一個文字檔。:max-bytes 可調截斷長度。"
  [sandbox &named max-bytes]
  (default max-bytes read-max-bytes)
  (reg/make-tool "read-file"
    "讀取一個檔案的內容（相對於工作目錄的路徑）。太長會截斷。"
    {:type "object"
     :properties {:path {:type "string" :description "檔案路徑，相對於工作目錄"}}
     :required ["path"]}
    (fn [args]
      (def real (sb/resolve-existing sandbox (get args :path)))
      (unless (= :file (os/stat real :mode))
        (error (string (get args :path) " 不是檔案")))
      (truncate (string (slurp real)) max-bytes))))

(defn- entry-line
  "list-dir 的一行：d 開頭是資料夾、f 是檔案（附大小）。"
  [dir name]
  (def full (path/join dir name))
  (def st (os/stat full))
  (case (get st :mode)
    :directory (string "d " name "/")
    :file      (string "f " name " (" (get st :size) " bytes)")
    (string "? " name)))

(defn list-dir-tool
  "list-dir：列出 root 底下某個資料夾的內容（沒給 path 就是 root 自己）。"
  [sandbox]
  (reg/make-tool "list-dir"
    "列出資料夾裡有哪些檔案與子資料夾。path 省略時列工作目錄本身。"
    {:type "object"
     :properties {:path {:type "string" :description "資料夾路徑，相對於工作目錄；省略＝工作目錄"}}
     :required []}
    (fn [args]
      (def real (sb/resolve-existing sandbox (get args :path ".")))
      (unless (= :directory (os/stat real :mode))
        (error (string (get args :path) " 不是資料夾")))
      (def names (sorted (os/dir real)))
      (if (empty? names)
        "（空資料夾）"
        (string/join (map |(entry-line real $) names) "\n")))))

(defn write-file-tool
  "write-file：把整段內容寫進 root 底下的一個檔（覆蓋）。sandbox 沒開 :write? 會回拒絕。"
  [sandbox]
  (reg/make-tool "write-file"
    "把內容寫進檔案（整檔覆蓋；檔案不存在就新建，上層資料夾要先存在）。"
    {:type "object"
     :properties {:path    {:type "string" :description "檔案路徑，相對於工作目錄"}
                  :content {:type "string" :description "要寫進去的完整內容"}}
     :required ["path" "content"]}
    (fn [args]
      (def real (sb/resolve-for-write sandbox (get args :path)))
      (def content (string (get args :content "")))
      (spit real content)
      (string "已寫入 " (sb/display-path sandbox real) "（" (length content) " bytes）"))))

(defn fs-tools
  ``一組檔案工具：read-file、list-dir，sandbox 開了 :write? 才多一個 write-file。
  search-files 在 tools-search.janet，自己加。``
  [sandbox &named max-bytes]
  (def out @[(read-file-tool sandbox :max-bytes max-bytes) (list-dir-tool sandbox)])
  (when (sandbox :write?) (array/push out (write-file-tool sandbox)))
  out)
