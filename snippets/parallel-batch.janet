#!/usr/bin/env janet
# 並行跑一批工作，而且**限制同時幾個**、**一個失敗不拖垮整批**。
# 跑法：janet snippets/parallel-batch.janet
#
# 為什麼要這支：
#   * spork/ev-utils 的 pmap 已經支援 n-workers（限流），而且**結果保序**——這兩點很好
#   * ⚠ 但它「一個失敗整批丟出」。真的批次工作通常要的是「成功的收下、失敗的記起來」
#   * 打 API、跑子行程、讀一堆檔都是這個形狀
#
# 相關：docs/30（pmap 保序）、docs/15（ev）、snippets/retry-timeout.janet

(import spork/ev-utils :as eu)

# ── 1. 限流：pmap 的第三個參數 ────────────────────────────────
# (eu/pmap f 資料 n) —— 同時最多 n 個。不給就全開。
# ⚠ 不是「開 n 條執行緒」，是 n 個 fiber；CPU 密集的工作要用 ev/thread（docs/15）

# ── 2. 一個失敗不拖垮整批 ────────────────────────────────────
(defn 批次
  ``並行跑 f 過每個 item，回 @{:ok @[…] :err @[…]}。

  :併發   同時最多幾個（預設 4）
  :逾時   每個工作的秒數上限；nil 表示不限
  :進度   (fn [做完幾個 總共] …)，每完成一個呼叫一次

  ⚠ 跟 eu/pmap 的差別就在這裡：它一個失敗就整批丟出，這裡把例外接在
    **每個工作內部**，所以壞掉的那幾個不會影響其他的。``
  [f items &named 併發 逾時 進度]
  (default 併發 4)
  (def 總共 (length items))
  (var 做完 0)
  (def 結果
    (eu/pmap
      (fn [[i item]]
        (def r
          (protect (if 逾時 (ev/with-deadline 逾時 (f item)) (f item))))
        (++ 做完)
        (when 進度 (進度 做完 總共))
        [i item r])
      (pairs (array ;items))          # 帶著索引跑，才知道誰是誰
      併發))
  (def ok @[]) (def err @[])
  # pmap 保序，但我們還是照索引放回去，這樣就算換成別的實作也不會錯
  (each [i item [成功? 值]] (sorted-by first 結果)
    (if 成功?
      (array/push ok  {:i i :item item :值 值})
      (array/push err {:i i :item item :錯 值})))
  @{:ok ok :err err})

# ── 示範 ─────────────────────────────────────────────────────
(defn 進度條 [做完 總共]
  # ⚠ \r 只在終端機有意義；接管線時每筆換行才不會擠成一行（見 snippets/term-color.janet）
  (if (os/isatty stdout)
    (do (prin "\r  進度 " (string/repeat "█" 做完) (string/repeat "░" (- 總共 做完))
              (string/format " %d/%d" 做完 總共))
        (:flush stdout))
    (when (= 做完 總共) (printf "  進度 %d/%d（接管線時只印最後一筆）" 做完 總共))))

(defn main [&]
  (print "\n── ① pmap 的 n-workers 真的有限流 ──────────────────")
  (var 同時 0) (var 最高 0)
  (defn 工作 [x] (++ 同時) (set 最高 (max 最高 同時)) (ev/sleep 0.05) (-- 同時) (* x 10))
  (each n [nil 3 12]
    (set 同時 0) (set 最高 0)
    (def t0 (os/clock :monotonic))
    (def r (eu/pmap 工作 (range 12) n))
    (printf "  n-workers=%-5s 最高同時=%-3d 耗時=%.2fs  結果前四個 %j"
            (if n (string n) "不給") 最高 (- (os/clock :monotonic) t0) (take 4 r)))
  (print "  ⚠ 這是 fiber 不是執行緒——CPU 密集的工作要用 ev/thread（docs/15）")

  (print "\n── ② 結果保序（即使先跑完的先回來）──────────────────")
  (printf "  %j" (eu/pmap (fn [x] (ev/sleep (/ (- 5 x) 100)) x) [0 1 2 3 4] 5))
  (print "  ↑ 第 4 個最快跑完，但結果還是 0 1 2 3 4")

  (print "\n── ③ ⚠ pmap 一個失敗整批丟出 ──────────────────")
  (printf "  %s"
          (try (eu/pmap (fn [x] (if (= x 3) (error "第3個壞了") x)) (range 6) 2)
               ([e] (string "整批丟出：" e))))
  (print "  ↑ 前面五個明明成功了，你也拿不到")

  (print "\n── ④ 批次：成功的收下、失敗的記起來 ──────────────────")
  (def r (批次 (fn [x]
                 (ev/sleep 0.02)
                 (cond (= x 3) (error "第3個壞了")
                       (= x 7) (error "第7個也壞了")
                       (* x x)))
               (range 10)
               :併發 3 :進度 進度條))
  (when (os/isatty stdout) (print))
  (printf "  成功 %d 個：%j" (length (r :ok)) (map |($ :值) (r :ok)))
  # ⚠ 用 %s 不用 %j——中文錯誤訊息在 %j 下會被逃逸成 \xE7\xAC\xAC…（docs/01）
  (printf "  失敗 %d 個：%s" (length (r :err))
          (string/join (map |(string/format "item %j → %s" ($ :item) ($ :錯)) (r :err)) "、"))
  (print "  ↑ 壞掉的兩個沒有拖垮其他八個")

  (print "\n── ⑤ 每個工作各自限時 ──────────────────")
  (def r2 (批次 (fn [x] (ev/sleep (if (even? x) 0.02 1)) x)
                (range 6) :併發 6 :逾時 0.2))
  (printf "  成功 %j" (map |($ :item) (r2 :ok)))
  (printf "  逾時 %j" (map |($ :item) (r2 :err)))
  (print "  ↑ 奇數的睡 1 秒，被 0.2 秒的 deadline 砍掉，偶數的照樣完成")

  (print "\n✓ parallel-batch 跑完"))
