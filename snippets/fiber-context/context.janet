# 模仿 Go 的 context.Context，用來管控一群 fiber：取消、逾時、傳值、階層傳播。
#
# Go 的 context 三個要素，在 Janet 分別對應到：
#   ctx.Done()  → 一個永遠不會被寫入、只會被 close 的 channel（ev/chan-close）
#   ctx.Err()   → 我們自己記在 ctx 裡的 :err
#   ctx.Value() → 一張 table，子 context 用 prototype 繼承父的值
#
# ★ Janet 的取消是「合作式」的：ev/cancel 只對 ev 排程的 task fiber 有效，
#   而且要等對方下次進入 ev 操作（ev/sleep、ev/take、net 讀寫…）才會生效。
#   純 CPU 迴圈不會被打斷——這點跟 Go 一樣，要自己在迴圈裡檢查 (cancelled? ctx)。

(defn background
  "根 context：沒有取消條件，什麼都不做。"
  []
  @{:done   (ev/chan)          # 只用 close 當訊號，從不 give
    :err    nil
    :values @{}
    :kids   @[]})

(defn cancelled?
  "非阻塞地問：這個 context 被取消了嗎？"
  [ctx]
  (not (nil? (ctx :err))))

(defn done-chan
  "拿 done channel，給 ev/select 用：誰先來就跑誰。"
  [ctx]
  (ctx :done))

(defn cancel
  "取消這個 context 和它底下所有子 context。可重入（第二次呼叫沒作用）。"
  [ctx &opt reason]
  (default reason :cancelled)
  (unless (cancelled? ctx)
    (put ctx :err reason)
    (ev/chan-close (ctx :done))    # 所有等在 done 上的 fiber 立刻醒來
    # ★ 把還在睡的計時器一起收掉，否則它會讓 ev 迴圈活到逾時那一刻，
    #   程式明明做完了卻不肯結束（Go 要你 defer cancel() 就是同一個理由）
    (when-let [t (ctx :timer)] (protect (ev/cancel t :ctx-cancelled)))
    (each k (ctx :kids) (cancel k reason)))
  ctx)

(defn with-cancel
  "開一個子 context：父被取消時它也被取消，但取消它不影響父。"
  [parent]
  (def child @{:done   (ev/chan)
               :err    (parent :err)
               :values (table/setproto @{} (parent :values))   # 值用 prototype 繼承
               :kids   @[]})
  (array/push (parent :kids) child)
  (when (cancelled? parent) (cancel child (parent :err)))
  child)

(defn with-timeout
  "開一個 sec 秒後自動取消的子 context。
  ★ 用完記得 cancel（即使工作提早做完）——不然那個計時 fiber 會吊住 ev 迴圈。"
  [parent sec]
  (def child (with-cancel parent))
  (put child :timer
       # try 包住：計時器被提早 ev/cancel 掉時，別把例外冒到 supervisor 去印堆疊
       (ev/go (fn [] (try (do (ev/sleep sec) (cancel child :timeout)) ([_] nil)))))
  child)

(defn with-value
  "帶一個 key/value 的子 context（Go 的 context.WithValue）。"
  [parent k v]
  (def child (with-cancel parent))
  (put (child :values) k v)
  child)

(defn value
  "查值，查不到就往父層找（靠 table prototype 自動完成）。"
  [ctx k &opt dflt]
  (or (get (ctx :values) k) dflt))

(defn check
  "在長工作的迴圈裡呼叫：被取消就丟例外，讓上層 try 接住。"
  [ctx]
  (when (cancelled? ctx)
    (error (ctx :err))))

(defn go
  "把一份工作掛到 context 底下跑。f 收 ctx 一個參數。
  回傳 task fiber，可以再 (ev/cancel …) 硬砍。"
  [ctx f]
  (ev/go (fn [] (f ctx))))

(defn wait
  "等工作做完或 context 被取消，兩者取先到的那個。
  回傳 [:ok 值] 或 [:cancelled 原因]。"
  [ctx work-chan]
  (def [kind chan v] (ev/select (done-chan ctx) work-chan))
  (if (= chan (done-chan ctx))
    [:cancelled (or (ctx :err) :closed)]
    (if (= kind :close) [:cancelled :work-channel-closed] [:ok v])))
