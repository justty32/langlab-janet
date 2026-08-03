#!/usr/bin/env janet
# 模仿 shell 管道：起一個子程式，每秒往它的 stdin 寫一行，寫十次後送 EOF，
# 同時即時把它的 stdout 收下來。
#
# 跑法：
#   sh snippets/pipe-to-child/build.sh          # 先編出示範子程式（沒編也能跑，見下）
#   janet snippets/pipe-to-child/main.janet
#   janet snippets/pipe-to-child/main.janet cat 3 0.2   # 換成 cat、3 次、每 0.2 秒
#
# 重點：
#   * (os/spawn cmd :px {:in :pipe :out :pipe}) 才會給你 pipe；:p=用 PATH、:x=非零報錯
#   * 寫：(:write (p :in) s)     關：(:close (p :in)) ← 這一關就是送 EOF
#   * 讀：(:read (p :out) n) 讀最多 n bytes，回 nil 表示對方關了
#   * ★ 讀寫要放在不同 fiber，否則對方輸出塞滿 pipe buffer 時會互相卡死
#   * ★ 收工一定要 (os/proc-wait p)，否則留下殭屍行程

(import spork/path)

(defn spawn-with-pipes
  "起一個子行程，stdin/stdout 都接管線。"
  [cmd]
  (os/spawn cmd :px {:in :pipe :out :pipe}))

(defn pump-stdout
  "背景 fiber：把子行程的輸出一塊塊收下來、順手印出來，回傳收集用的 buffer。"
  [proc]
  (def collected @"")
  (ev/spawn
    (while true
      (def chunk (:read (proc :out) 4096))
      (if (nil? chunk) (break))              # nil = 對方關了 stdout
      (buffer/push collected chunk)
      (prin chunk)
      (flush)))
  collected)

(defn feed
  "每 interval 秒往 stdin 寫一行，共 times 次，然後關掉 stdin 送 EOF。"
  [proc times interval]
  (for i 0 times
    (def line (string/format "第 %d 筆 @ %d\n" (inc i) (os/time)))
    (prin "[parent] 送出：" line)
    (flush)
    (:write (proc :in) line)
    (ev/sleep interval))
  (printf "[parent] %d 次送完，關 stdin（= 送 EOF）" times)
  (flush)
  (:close (proc :in)))                       # ★ EOF 就是「關掉自己這端的寫入」

(defn main [& args]
  # 位置參數：給 "-" 表示「這個用預設」
  (defn arg [i] (let [v (get args i)] (if (or (nil? v) (= v "-") (= v "")) nil v)))

  # 從「這支檔自己的位置」算出 child 的路徑，所以在哪個目錄跑都對
  (def child-path (string (path/dirname (dyn :current-file)) "child"))
  (def cmd (cond
             (arg 1)                     [(arg 1)]
             (os/stat child-path :mode)  [child-path]
             (do (print "找不到 ./child，改用 cat 示範。")
                 (print "要編：sh snippets/pipe-to-child/build.sh\n")
                 ["cat"])))
  (def times    (if-let [v (arg 2)] (scan-number v) 10))
  (def interval (if-let [v (arg 3)] (scan-number v) 1))

  (printf "跑 %q，每 %g 秒一次，共 %d 次\n" cmd interval times)
  (def proc (spawn-with-pipes cmd))
  (def out (pump-stdout proc))               # 先開始讀，再開始寫（避免卡死）
  (feed proc times interval)

  (def code (os/proc-wait proc))             # ★ 等它收屍
  (printf "\n[parent] 子行程結束，exit code = %d，總共收到 %d bytes"
          code (length out)))
