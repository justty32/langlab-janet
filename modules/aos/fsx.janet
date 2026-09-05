# 檔案協定的底層工具：id、時間戳、原子寫、json 讀寫、O_EXCL 鎖。
# 這一層不認識 aos 的任何概念，只管「照 spec 07 的寫法把位元組放到磁碟上」。
#
# ⚠ Janet 標準庫**沒有 fsync**（只有 file/flush，刷到 OS 不是刷到碟）。
#   spec S-07-33／S-07-66 要求「寫→fsync→rename→fsync 目錄」，這裡只做得到
#   「寫→flush→rename」。斷電時的保證比 Python 原型弱，記在 FINDINGS-踩坑c。

(import spork/json)
(import spork/path)

(defn now-iso
  "ISO 8601 UTC 含毫秒，spec 的時間戳格式（例 2026-09-05T12:00:00.000Z）。"
  []
  (def t (os/clock :realtime))
  (def d (os/date (math/floor t)))   # 第二引數是 local，省略＝UTC
  (def ms (math/floor (* 1000 (- t (math/floor t)))))
  (string/format "%04d-%02d-%02dT%02d:%02d:%02d.%03dZ"
                 (d :year) (inc (d :month)) (inc (d :month-day))
                 (d :hours) (d :minutes) (d :seconds) ms))

(defn new-id
  "機器產的 id：32 個小寫 hex（spec S-07-35）。"
  []
  (string/join (map |(string/format "%02x" $) (os/cryptorand 16))))

(defn hex-id?
  "是不是 32 個小寫 hex。"
  [x]
  (and (string? x) (= 32 (length x))
       (all |(or (<= 48 $ 57) (<= 97 $ 102)) x)))

(defn string-args
  "把呼叫 args 的鍵值變字串，並擋下不能變成 AOS_ARG_* 的鍵。"
  [args]
  (def out @{})
  (eachp [k v] (or args {})
    (def s (string k))
    (unless (and (not (empty? s))
                 (or (= 95 (in s 0)) (<= 65 (in s 0) 90) (<= 97 (in s 0) 122))
                 (all |(or (= 95 $) (<= 48 $ 57) (<= 65 $ 90) (<= 97 $ 122)) s))
      (errorf "呼叫參數名 %q 不能變成 AOS_ARG_*（S-07-13）" s))
    (put out s (string v)))
  out)

(defn ensure-dir
  "遞迴建目錄（mkdir -p）。已經在就當沒事。"
  [dir]
  (def parts (string/split "/" dir))
  (var acc (if (string/has-prefix? "/" dir) "" nil))
  (each p parts
    (unless (empty? p)
      (set acc (if acc (string acc "/" p) p))
      (os/mkdir acc)))
  dir)

(defn atomic-write
  ``原子寫：同目錄開 `.tmp` → flush → rename。spec S-07-66「暫存檔禁止開在別的目錄」。``
  [p text]
  (ensure-dir (path/dirname p))
  (def tmp (string p ".tmp." (new-id)))
  (with [f (file/open tmp :w)]
    (file/write f text)
    (file/flush f))
  (os/rename tmp p)
  p)

(defn write-json [p obj] (atomic-write p (string (json/encode obj "  " "\n") "\n")))

(defn read-json
  "讀不到（或不是 json）就回 dflt，不丟例外——三態要靠「檔在不在」判，不能被例外打斷。"
  [p &opt dflt]
  (if (= :file (os/stat p :mode))
    (let [[ok v] (protect (json/decode (slurp p) true))] (if ok v dflt))
    dflt))

(defn denull
  "⚠ spork/json 把 json 的 null 解成 **keyword :null**，不是 nil。忘了這件事的話
  `(nil? (res :exit_code))` 永遠是 false，兩個頻道就分不開了。"
  [v]
  (if (= :null v) nil v))

(defn exists? [p] (and (string? p) (not (nil? (os/stat p :mode)))))

(defn pid-alive?
  "Linux：/proc/<pid> 在不在。登記表的 daemon_pid 與 pid 都靠這個判。"
  [pid]
  (and (number? pid) (> pid 0) (= :directory (os/stat (string "/proc/" pid) :mode))))

(defn lock-acquire
  ``獨佔鎖。⚠ Janet 的 file/open **沒有 O_EXCL**（:wx 會被擋成 invalid flag），
  所以用 os/link：先寫一個暫存檔，再硬連結到鎖路徑——目標已存在就 link 失敗。
  這樣跟 Python 原型的 O_EXCL 建檔互通（兩邊看到的都是一個普通檔）。``
  [lock-path &opt wait-ms]
  (default wait-ms 5000)
  (def src (string lock-path ".mk." (new-id)))
  (ensure-dir (path/dirname lock-path))
  (atomic-write src (json/encode {:pid (os/getpid) :at (now-iso)}))
  (defer (os/rm src)
    (var left wait-ms)
    (var got false)
    (while (and (not got) (>= left 0))
      (if (first (protect (os/link src lock-path)))
        (set got true)
        (do # 持鎖者死了就把鎖收回來（原型 fsutil.Lock 也這樣）
          (def info (read-json lock-path {}))
          (if (and (info "pid") (not (pid-alive? (info "pid"))))
            (protect (os/rm lock-path))
            (do (os/sleep 0.02) (-= left 20))))))
    (unless got
      (errorf "鎖被佔住：%s（等了 %d ms）。下一步：確認沒有 aos 行程在跑，再手動刪掉那個檔"
              lock-path wait-ms))
    lock-path))

(defn lock-release [lock-path] (protect (os/rm lock-path)) nil)

(defmacro with-lock [lock-path & body]
  ~(do (,lock-acquire ,lock-path) (defer (,lock-release ,lock-path) ,;body)))
