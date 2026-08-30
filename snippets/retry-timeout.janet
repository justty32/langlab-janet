#!/usr/bin/env janet
# 重試與逾時——打外部服務（HTTP、子行程、DB）時一定會用到的兩件事。
# 跑法：janet snippets/retry-timeout.janet
#
# 重點：
#   * 逾時用 (ev/with-deadline sec & body)，超時丟 "deadline expired"，可以 try 接
#   * 退避一定要加 jitter，否則一群 client 同時失敗會同時重試（thundering herd）
#   * ⚠ jitter 別用裸的 math/random——它每次跑程式都給同一串（見 docs/26）
#   * 不是所有錯誤都該重試：打錯字的 URL 重試一百次還是打錯字

(import spork/misc)

# ── 逾時 ──────────────────────────────────────────────────────
(defn 限時
  ``跑 f，最多等 sec 秒。超時丟 "deadline expired"。``
  [sec f]
  (ev/with-deadline sec (f)))

(defn 限時-或 [sec f 預設]
  "超時就回預設值，不拋錯。"
  (try (限時 sec f) ([e] (if (= e "deadline expired") 預設 (error e)))))

# ── 退避 ──────────────────────────────────────────────────────
# ⚠ 用自己的 rng：裸的 math/random 每次跑程式都給同一串，
#   那樣 jitter 就失去意義了（docs/26 的頭號坑）。
(def rng (math/rng (os/cryptorand 8)))

(defn 退避秒數
  ``指數退避 ＋ 抖動。第 n 次（從 0 起算）等 base*2^n，再乘上 0.5～1.0 的隨機係數。
  cap 是上限，免得等到天荒地老。``
  [n &named base cap]
  (default base 0.1)
  (default cap 5)
  (def 理想 (min cap (* base (math/pow 2 n))))
  (* 理想 (+ 0.5 (* 0.5 (math/rng-uniform rng)))))

# ── 重試 ──────────────────────────────────────────────────────
(defn 重試
  ``跑 f，失敗就重試。全部失敗才把最後一個錯誤丟出來。

  :次數      總共嘗試幾次（含第一次），預設 3
  :該重試?   (fn [err] …) 回真才重試；預設全部重試
  :每次逾時  每次嘗試的秒數上限；nil 表示不限
  :記錄      (fn [n err 等幾秒] …) 每次失敗時呼叫，方便印 log``
  [f &named 次數 該重試? 每次逾時 記錄]
  (default 次數 3)
  (default 該重試? (fn [_] true))
  (var 最後錯 nil)
  (var 成功? false)
  (for n 0 次數
    (def [ok 結果]
      (protect (if 每次逾時 (限時 每次逾時 f) (f))))
    # ⚠ 一定要用明確的旗標。只靠「最後錯 是不是 nil」判斷會出錯：
    #   第 3 次成功時，最後錯 還留著第 2 次的值，於是明明成功卻照樣拋。
    (when ok (set 成功? true) (break))
    (set 最後錯 結果)
    (def 還有下次 (< n (dec 次數)))
    (cond
      (not (該重試? 結果))
      (do (when 記錄 (記錄 (inc n) 結果 nil)) (break))

      還有下次
      (let [等 (退避秒數 n)]
        (when 記錄 (記錄 (inc n) 結果 等))
        (ev/sleep 等))

      (when 記錄 (記錄 (inc n) 結果 nil))))
  (unless 成功? (error 最後錯)))

(defn 重試-取值
  "同上，但成功時回傳 f 的結果。"
  [f & opts]
  (var 值 nil)
  (重試 (fn [] (set 值 (f))) ;opts)
  值)

# ── 示範 ─────────────────────────────────────────────────────
(defn 記log [n err 等]
  (printf "    第 %d 次失敗：%s%s" n (string err)
          (if 等 (string/format "，%.2f 秒後重試" 等) "，放棄")))

(defn main [&]
  (print "\n── 逾時 ──────────────────")
  (printf "  來得及做完      => %j" (限時 1 (fn [] (ev/sleep 0.05) :做完了)))
  (printf "  來不及          => %s"
          (try (限時 0.1 (fn [] (ev/sleep 2) :做完了)) ([e] (string "丟出 " e))))
  (printf "  超時給預設值    => %j" (限時-或 0.1 (fn [] (ev/sleep 2) :做完了) :預設))
  (print "  ⚠ 超時後整個程式還活著——被取消的只有那個 fiber")

  (print "\n── 退避有抖動（同一次 n 每次都不同）──────────────────")
  (each n [0 1 2 3]
    # ⚠ 這裡不能寫 |(…)——短函式沒有 $ 就是 0 參數，map 會傳 1 個進來（docs/33）
    (printf "  第 %d 次退避：%s" n
            (string/join (seq [_ :range [0 3]] (string/format "%.3f" (退避秒數 n))) "  ")))
  (print "  ⚠ 沒有 jitter 的話，一群 client 同時失敗會同時重試，把後端再打掛一次")

  (print "\n── 重試：第 3 次才成功 ──────────────────")
  (var 次 0)
  (def r (重試-取值 (fn [] (++ 次) (if (< 次 3) (error "暫時性失敗") :終於成功))
                    :次數 5 :記錄 記log))
  (printf "  結果 => %j（跑了 %d 次）" r 次)

  (print "\n── 重試：全部失敗，最後把錯誤丟出來 ──────────────────")
  (printf "  %s" (try (重試 (fn [] (error "一直壞")) :次數 3 :記錄 記log)
                      ([e] (string "最後丟出：" e))))

  (print "\n── ⚠ 不該重試的錯誤要立刻放棄 ──────────────────")
  (defn 值得重試? [e]
    (def s (string e))
    (or (string/find "timeout" s) (string/find "connection" s) (string/find "暫時" s)))
  (var 次2 0)
  (printf "  %s" (try (重試 (fn [] (++ 次2) (error "404 not found"))
                            :次數 5 :該重試? 值得重試? :記錄 記log)
                      ([e] (string "最後丟出：" e))))
  (printf "  只跑了 %d 次——打錯字的 URL 重試一百次還是打錯字" 次2)

  (print "\n── 兩個合起來：每次嘗試都限時 ──────────────────")
  (var 次3 0)
  (printf "  %s"
          (try (重試 (fn [] (++ 次3) (ev/sleep 2))    # 每次都會超時
                     :次數 3 :每次逾時 0.1 :記錄 記log)
               ([e] (string "最後丟出：" e))))

  (print "\n✓ retry-timeout 跑完"))
