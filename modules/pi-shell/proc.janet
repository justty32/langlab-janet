# 子行程管線層 —— 起一支外部指令、餵 stdin、收 stdout、等它收屍。
# 這一層完全不知道 pi／claude 是什麼，只管管線；agent 的知識在 init.janet。
#
# ── 兩個方向刻意用**不同**的做法，原因不一樣 ────────────────────────
#
# stdout：管線 ＋ 背景 fiber 邊跑邊讀。
#   ★ 讀一定要跟主流程分開跑，否則子行程輸出塞滿 pipe buffer 時兩邊互卡。
#   別改成「先 os/proc-wait 再讀」——輸出量一大就死鎖。
#
# stdin：★ 走**已經填好內容的暫存檔句柄**，不是 spawn 後才寫的管線。
#   為什麼見下面 feed-file 的說明；這是實測踩出來的，別改回管線。
#
# 其餘：
#   * :p = 走 PATH 找執行檔；刻意不加 :x —— 非 0 退出碼要當**資料**回傳給呼叫端
#     判斷，不是丟例外炸掉。
#   * ★ 收工一定要 (os/proc-wait proc)，否則留下殭屍行程。
#   * stderr 不接管線、直接繼承本行程的，所以子行程的進度訊息會照常出現在終端。

(defn drain
  "背景 fiber：把某個管線一路讀到對方關閉（讀到 nil）。回傳收集用的 buffer。
  ★ 一定要在開始寫 stdin **之前**先呼叫它，否則對方輸出塞滿 buffer 會互卡。"
  [stream]
  (def collected @"")
  (ev/spawn
    (while true
      (def chunk (:read stream 4096))
      (if (nil? chunk) (break))
      (buffer/push collected chunk)))
  collected)

(defn feed-file
  ``把一段字串包成「內容已經就緒」的匿名暫存檔句柄，給 os/spawn 當 :in 用。

  ★ 為什麼不用管線：有些 CLI（`pi` 就是）在**啟動當下**檢查 stdin 有沒有東西可讀。
    shell 的 `echo x | pi` 在 pi 開始跑之前資料就已經躺在管線 buffer 裡；但 os/spawn
    ＋ `:in :pipe` 是**先 spawn、後寫入**，pi 檢查的那一瞬間管線還是空的，於是它判定
    「沒有管線輸入」。改成先把內容寫進暫存檔、再把**已經填好的**句柄交給子行程，
    子行程一開工就讀得到，時序問題就不存在了。
    （`claude -p` 與一般 node 程式是事件式等到 EOF，對這個時序不敏感，所以看不出差別
    ——但統一走這條路對兩者都有效，也比管線＋背景 fiber 寫入更簡單。）

  ⚠ `(file/seek f :set 0)` **一定要做**：寫完之後檔案指標停在檔尾，不倒帶的話子行程
    從檔尾開始讀 = **靜默讀到空**，不會有任何錯誤訊息，非常難查。

  file/temp 是匿名暫存檔，(file/close …) 掉就消失，不用自己刪檔。``
  [s]
  (def f (file/temp))
  (file/write f s)
  (file/flush f)
  (file/seek f :set 0)                 # ★ 倒帶，否則子行程讀到空
  f)

(defn run
  ``跑一次子行程，回 @{:out "它的 stdout" :code 退出碼}。

  cmd       —— 完整的指令陣列（含執行檔名）
  stdin-str —— 可省略；有給就先寫進暫存檔再當子行程的 stdin（見 feed-file）。
               沒給就給一條立刻關掉的管線，讓子行程馬上讀到 EOF、不會空等。``
  [cmd &opt stdin-str]
  (def feed (when (and stdin-str (not (empty? stdin-str)))
              (feed-file stdin-str)))
  (def proc (os/spawn cmd :p {:in (or feed :pipe) :out :pipe}))
  (def out (drain (proc :out)))        # ★ 邊跑邊讀，別等 proc-wait
  (unless feed
    (:close (proc :in)))               # 沒東西要餵 → 關掉這端 = 立刻送 EOF
  (def code (os/proc-wait proc))       # ★ 收屍
  (when feed (file/close feed))        # 匿名暫存檔，close 掉就消失
  @{:out (string out) :code code})

(defn available?
  "PATH 上找不找得到這支執行檔（用 `<cmd> --version` 探測）。"
  [cmd]
  (def [ok res] (protect (run [cmd "--version"])))
  (and ok (= 0 (res :code))))
