#!/usr/bin/env janet
# 每 5 秒印一次當前時間（Ctrl-C 結束）。
# 跑法：janet snippets/every-5s-clock.janet [間隔秒數] [次數]
#
# 重點：
#   * (os/date) 的 :month 和 :month-day 是 0-based，要 +1 才是人看的月/日
#   * (ev/sleep n) 是 ev 事件迴圈的睡眠，不是 busy-wait，也不擋其他 fiber
#   * 想「邊睡邊做別的事」把工作丟 (ev/spawn ...)，不必改成 callback

(defn now-string
  "把 (os/date) 轉成 YYYY-MM-DD HH:MM:SS。&opt utc 為真則用 UTC。"
  [&opt utc]
  (def d (os/date (os/time) utc))
  (string/format "%04d-%02d-%02d %02d:%02d:%02d"
                 (d :year)
                 (inc (d :month))       # ★ 0-based
                 (inc (d :month-day))   # ★ 0-based
                 (d :hours) (d :minutes) (d :seconds)))

(defn tick-forever
  "每 interval 秒呼叫一次 f。times 給了就只跑那麼多次。"
  [interval f &opt times]
  (var n 0)
  (while (or (nil? times) (< n times))
    (f n)
    (++ n)
    (when (or (nil? times) (< n times))
      (ev/sleep interval))))

(defn main [& args]
  # ★ 用 (get args 1) 不要用 (args 1)：tuple 索引越界會直接報錯，get 才回 nil
  (def interval (if-let [v (get args 1)] (scan-number v) 5))
  (def times    (if-let [v (get args 2)] (scan-number v) nil))
  (printf "每 %g 秒印一次%s，Ctrl-C 結束"
          interval (if times (string "，共 " times " 次") ""))

  # 順便示範：主迴圈在睡的時候，背景 fiber 照樣在跑
  (ev/spawn
    (ev/sleep (/ interval 2))
    (print "    （背景 fiber：主迴圈在 ev/sleep 時我照跑）"))

  (tick-forever interval
                (fn [i] (printf "[%d] %s" i (now-string)))
                times))
