#!/usr/bin/env janet
# 非同步（handler 風格）處理 stdin：註冊回呼，資料來了才被叫，期間主線照跑。
# 跑法：
#   printf 'hello\nworld\n' | janet snippets/stdin-async.janet
#   janet snippets/stdin-async.janet            # 互動：自己打字，Ctrl-D 結束
#   yes | head -100000 | janet snippets/stdin-async.janet   # 灌大量資料
#
# 重點：
#   * ★ 內建的 stdin 是 :core/file，(file/read stdin :line) 會擋住「整個」ev 迴圈
#   * 要非阻塞就自己開一條 stream：(os/open "/dev/stdin" :r) → :core/stream
#   * stream 才能用 (ev/read s n)，它只擋住當前 fiber，其他 fiber 照跑
#   * ev/read 回 nil = EOF（對方關了）
#   * 讀進來的是「一塊」不是「一行」，行的邊界要自己切（見 make-line-reader）

(defn h [s] (printf "\n── %s" s))

# ── 把「一塊一塊的位元組」變成「一行一行的回呼」──────────────────────
(defn make-line-reader
  "回傳一個 (feed chunk) 函式：喂它任意大小的資料塊，
  湊滿一行就呼叫 on-line，剩下的留在緩衝區等下一塊。
  傳 nil 表示 EOF——這時把殘留的最後一行（沒有換行結尾的那種）也送出去。"
  [on-line]
  (def pending @"")
  (fn feed [chunk]
    (if (nil? chunk)
      (when (pos? (length pending))            # EOF：收尾
        (on-line (string pending))
        (buffer/clear pending))
      (do
        (buffer/push pending chunk)
        (var idx (string/find "\n" pending))
        (while idx
          (on-line (string (slice pending 0 idx)))
          (def leftover (buffer/slice pending (inc idx)))   # 換行之後剩下的
          (buffer/clear pending)
          (buffer/push pending leftover)
          (set idx (string/find "\n" pending)))))))

# ── 主角：註冊 handler，回傳一個「等它結束」的 channel ────────────────
(defn on-stdin
  "非阻塞地讀 stdin。每讀到一行就呼叫 (on-line 行 行號)；
  EOF 時呼叫 (on-eof 總行數)。立刻回傳一個 channel，take 它就等於等結束。"
  [on-line &opt on-eof]
  (def done (ev/chan 1))
  (def stream (os/open "/dev/stdin" :r))        # ★ 關鍵：file → stream
  (var n 0)
  (def feed (make-line-reader (fn [line] (++ n) (on-line line n))))
  (ev/spawn
    (defer (:close stream)
      (while true
        (def chunk (ev/read stream 4096))
        (if (nil? chunk) (break))               # nil = EOF
        (feed chunk))
      (feed nil)                                # 收尾那行
      (when on-eof (on-eof n))
      (ev/give done n)))
  done)

(defn main [&]
  (h "註冊 handler")
  (print "  資料來了才會被叫；沒資料時 CPU 是閒的，其他 fiber 照跑。")
  (print "  （互動模式打字後按 Enter，Ctrl-D 結束）\n")

  (def words @[])
  (def done
    (on-stdin
      # ── 這就是 handler ──
      (fn [line n]
        (array/push words ;(string/split " " line))
        (printf "  [第 %d 行] %d 字元：%s" n (length line) line))
      (fn [total]
        (printf "  [EOF] 共 %d 行" total))))

  # 證明主線沒被擋住：一個心跳 fiber 一直在跑
  # try 包住：被 ev/cancel 砍掉時別把例外冒到 supervisor 去印堆疊
  (def beat (ev/go (fn []
                     (try
                       (do (var i 0)
                           (forever
                             (ev/sleep 0.25)
                             (printf "  ♥ 心跳 %d（主線沒被 stdin 擋住）" (++ i))))
                       ([_] nil)))))

  (def total (ev/take done))                   # 等 stdin 結束
  (ev/cancel beat :收工)                        # ★ 不砍它程式不會結束

  (h "統計")
  (printf "  行數 %d／字數 %d" total (length words))
  (printf "  前 5 個字：%s" (string/join (take 5 words) " "))

  (h "如果你不需要非同步")
  (print "  純粹要逐行處理、不在乎擋住：")
  (print "    (each line (file/lines stdin) …)     ← 最短")
  (print "    (while (def l (file/read stdin :line)) …)")
  (print "  只有在「同時要做別的事」（計時、連線、另一條 stream）時才需要本檔這套。")
  (print))
