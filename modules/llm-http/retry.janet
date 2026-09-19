# 重試 —— 只對「再試一次可能就好」的錯誤重試：連不上、HTTP 5xx、429。
#
# 400／401／404 這種重試一百次還是一樣，直接丟出去。做法抄自 snippets/retry-timeout.janet：
# 指數退避 ＋ 抖動（jitter），抖動用自己的 rng（裸的 math/random 每次跑都同一串）。
#
# 錯誤是靠**訊息文字**分類的（transport 層丟的都是字串）：
#   "連不上 …"           → 重試
#   "HTTP 5xx（…）"      → 重試
#   "HTTP 429（…）"      → 重試
#   其他                  → 不重試

(def- rng (math/rng (os/cryptorand 8)))

(def- status-peg
  (peg/compile ~(* "HTTP " (<- (3 :d)))))

(defn error-status
  "從 transport 的錯誤訊息裡挖出 HTTP 狀態碼；挖不到回 nil。"
  [msg]
  (when-let [m (peg/match status-peg (string msg))]
    (scan-number (m 0))))

(defn retryable?
  "這個錯誤值不值得重試（連線失敗、5xx、429）。"
  [msg]
  (def s (string msg))
  (or (string/has-prefix? "連不上" s)
      (let [st (error-status s)]
        (and st (or (>= st 500) (= st 429))))))

(defn backoff-seconds
  "第 n 次（0 起算）要等幾秒：base*2^n（上限 cap）再乘 0.5～1.0 的抖動。"
  [n &named base cap]
  (default base 0.5)
  (default cap 8)
  (* (min cap (* base (math/pow 2 n)))
     (+ 0.5 (* 0.5 (math/rng-uniform rng)))))

(defn with-retry
  ``跑 f，失敗且 retryable? 就退避後重試，最多**多試** times 次（times 0 ＝ 只跑一次）。

  times 可以是數字，也可以是 {:times n :base 秒 :cap 秒 :on-retry (fn [n err wait])}。
  全部失敗、或撞到不該重試的錯誤，就把那個錯誤原樣丟出去。``
  [times f]
  (def opts (if (dictionary? times) times {:times times}))
  (def n-max (or (opts :times) 0))
  (var result nil)
  (var done false)
  (var attempt 0)
  (while (not done)
    (def [ok v] (protect (f)))
    (cond
      ok (do (set result v) (set done true))
      (and (< attempt n-max) (retryable? v))
      (let [wait (backoff-seconds attempt :base (opts :base) :cap (opts :cap))]
        (++ attempt)
        (when-let [cb (opts :on-retry)] (cb attempt v wait))
        (ev/sleep wait))
      (error v)))
  result)
