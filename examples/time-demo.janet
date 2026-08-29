# 時間與日期 —— 配合 docs/24-時間與日期.md
#
# 跑法：janet examples/time-demo.janet
#
# ⚠ 這支印的是「跑的當下」的時間，所以每次輸出都不一樣，這是正常的。

(defn 標題 [s] (print "\n─── " s " ───"))

# ── 1. 時間點 = Unix 秒 ───────────────────────────────────────────────────
(標題 "1. os/time：整數、無時區")

(def now (os/time))
(printf "(os/time)  => %q   （整數？%q）" now (int? now))
(print "  這是 1970-01-01 00:00:00 UTC 起算的秒數，全世界同一瞬間拿到同一個數字。")

# ── 2. 給人看：os/strftime ────────────────────────────────────────────────
(標題 "2. os/strftime：第三參數 true 才是本地時間")

(printf "本地：%s" (os/strftime "%Y-%m-%d %H:%M:%S %Z" now true))
(printf "UTC ：%s" (os/strftime "%Y-%m-%d %H:%M:%S %Z" now))
(print "  ↑ 忘了給 true，時間就差一個時區——所有時間函式都是這個慣例。")

# ── 3. ⚠ os/date 的月與日是 0-based ───────────────────────────────────────
(標題 "3. os/date 的欄位（本篇最大的坑）")

(def d (os/date now true))
(printf "os/date => %q" d)
(print)
(printf "  :month     = %q ← 0-based！真正的月份是 %d"
        (d :month) (inc (d :month)))
(printf "  :month-day = %q ← 0-based！真正的日是   %d"
        (d :month-day) (inc (d :month-day)))
(printf "  :year      = %q ← 這個是正常的" (d :year))
(printf "  :hours     = %q ← 這個也是正常的" (d :hours))
(printf "  :week-day  = %q ← 0 = 星期日，今天是 %s"
        (d :week-day) (os/strftime "%A" now true))
(printf "  :year-day  = %q ← 一年的第幾天，也是 0-based（1/1 是 0）" (d :year-day))
(print)
(print "自己組字串就要記得 +1：")
(printf "  錯：%d-%02d-%02d   ← 少了 inc，八月會印成七月"
        (d :year) (d :month) (d :month-day))
(printf "  對：%d-%02d-%02d"
        (d :year) (inc (d :month)) (inc (d :month-day)))
(printf "  更好：%s   ← 交給 strftime，根本不會有這個問題"
        (os/strftime "%Y-%m-%d" now true))

# ── 4. 反向轉換與來回 round-trip ──────────────────────────────────────────
(標題 "4. os/mktime：欄位 → Unix 秒")

(def 生日 (os/mktime {:year 2026 :month 7 :month-day 28   # ← 也是 0-based
                      :hours 12 :minutes 0 :seconds 0} true))
(printf "{:year 2026 :month 7 :month-day 28 :hours 12} => %q" 生日)
(printf "轉回來看看：%s" (os/strftime "%Y-%m-%d %H:%M" 生日 true))
(printf "來回一圈會拿回原值嗎？ %q"
        (= now (os/mktime (os/date now true) true)))

# ── 5. 日期算術就是加減秒數 ───────────────────────────────────────────────
(標題 "5. 日期算術：時間戳是數字，直接加減")

(def 一天 86400)
(each n [-7 -1 0 1 3 30 365]
  (printf "  %+4d 天 => %s" n (os/strftime "%Y-%m-%d (%a)" (+ now (* n 一天)) true)))
(print "  跨月、跨年、閏年全部自動對，因為你算的是秒。")

# ── 6. 時長：計時要用 monotonic ───────────────────────────────────────────
(標題 "6. os/clock：三種來源")

(printf "  :realtime  => %q   牆上時鐘（會被校時改掉）" (os/clock :realtime))
(printf "  :monotonic => %q   單調遞增，計時用這個" (os/clock :monotonic))
(printf "  :cputime   => %q   這個行程真的用掉的 CPU 秒數" (os/clock :cputime))
(print)

(def t0 (os/clock :monotonic))
(def t0-cpu (os/clock :cputime))
(os/sleep 0.05)                       # 睡覺：有等待，但沒在算
(def 空轉 (reduce + 0 (range 200000))) # 算術：真的在燒 CPU
(printf "睡 0.05 秒 + 加總 20 萬個數字：")
(printf "  牆上時間 %.3f 秒（含睡的那 0.05）" (- (os/clock :monotonic) t0))
(printf "  CPU 時間 %.3f 秒（睡覺不算，所以比較小）" (- (os/clock :cputime) t0-cpu))
(print "  ↑ 兩者差很多 = 你的程式大多在等，不是在算。")

(print "\n完。單調時鐘的數值本身沒有意義，只有相減才有——不要拿它當時間點存起來。")
