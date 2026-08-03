#!/usr/bin/env janet
# 示範 context.janet：取消、逾時、值繼承、階層傳播。
# 跑法：janet snippets/fiber-context/main.janet

(import ./context :as ctx)

(defn h [s] (printf "\n── %s" s))

# 一份「會定期檢查自己該不該停」的工作
(defn worker [c name steps]
  (try
    (do
      (for i 0 steps
        (ctx/check c)                 # ★ 合作式取消：自己要記得問
        (ev/sleep 0.05)
        (printf "   %s 做完第 %d 步" name (inc i)))
      (printf "   %s 全部做完" name)
      :done)
    ([e] (printf "   %s 被中止：%q" name e) :aborted)))

(defn main [&]
  # ── 1) 手動取消 ────────────────────────────────────────────────
  (h "手動 cancel")
  (def root (ctx/background))
  (def c1 (ctx/with-cancel root))
  (ctx/go c1 (fn [c] (worker c "worker-A" 10)))
  (ev/sleep 0.15)
  (print "   （主線決定不等了）")
  (ctx/cancel c1 :使用者中止)
  (ev/sleep 0.1)

  # ── 2) 逾時自動取消 ────────────────────────────────────────────
  (h "with-timeout")
  (def c2 (ctx/with-timeout (ctx/background) 0.2))
  (ctx/go c2 (fn [c] (worker c "worker-B" 20)))
  (ev/sleep 0.4)
  (printf "   c2 的 err = %q" (c2 :err))

  # ── 3) 階層傳播：砍父的，子的一起死 ────────────────────────────
  (h "階層傳播")
  (def parent (ctx/with-cancel (ctx/background)))
  (def kid1 (ctx/with-cancel parent))
  (def kid2 (ctx/with-timeout parent 99))
  (ctx/go kid1 (fn [c] (worker c "kid-1" 20)))
  (ctx/go kid2 (fn [c] (worker c "kid-2" 20)))
  (ev/sleep 0.12)
  (print "   （砍 parent）")
  (ctx/cancel parent :父層收工)
  (ev/sleep 0.1)
  (printf "   kid1.err=%q  kid2.err=%q" (kid1 :err) (kid2 :err))

  # ── 4) with-value：子看得到父的值，父看不到子的 ────────────────
  (h "with-value（prototype 繼承）")
  (def base (ctx/with-value (ctx/background) :request-id "req-42"))
  (def sub  (ctx/with-value base :user "alice"))
  (printf "   sub 看 request-id = %q（繼承自父）" (ctx/value sub :request-id))
  (printf "   sub 看 user       = %q" (ctx/value sub :user))
  (printf "   base 看 user      = %q ← 看不到子的" (ctx/value base :user))
  (printf "   查不到給預設      = %q" (ctx/value base :nope :預設))

  # ── 5) select：工作完成 vs context 被取消，誰先來聽誰的 ─────────
  (h "wait：搶快")
  (defn race [sec-work sec-timeout]
    (def c (ctx/with-timeout (ctx/background) sec-timeout))
    (def result (ev/chan 1))
    (ctx/go c (fn [_] (ev/sleep sec-work) (ev/give result :工作結果)))
    (def r (ctx/wait c result))
    (ctx/cancel c :用完了)          # ★ 相當於 Go 的 defer cancel()，把計時器收掉
    r)
  (printf "   工作 0.1s / 逾時 0.3s => %q" (race 0.1 0.3))
  (printf "   工作 0.3s / 逾時 0.1s => %q" (race 0.3 0.1))

  # ── 6) 硬砍：ev/cancel 直接把 task fiber 打斷 ───────────────────
  (h "ev/cancel（不合作也砍得掉，但只在 ev 操作處生效）")
  (def task (ev/go (fn [] (try (forever (ev/sleep 0.05))
                               ([e] (printf "   task 被 ev/cancel：%q" e))))))
  (ev/sleep 0.1)
  (ev/cancel task :硬砍)
  (ev/sleep 0.1)
  (print))
