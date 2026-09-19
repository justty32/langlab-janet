# 記憶 —— 對話歷史（messages 陣列）的管理：append、粗估 token、截斷。存檔／讀回在 memory-io.janet。
#
# 一份 memory 就是 @{:messages @[…] :max-turns n :max-chars n}。system 訊息（有的話）永遠是第 0 則。
#
# ── 截斷怎麼做（trim!）────────────────────────────────────────────
# 以「輪」為單位：一輪 = 從一則 user 訊息開始、到下一則 user 之前的所有東西
# （assistant 的 tool_calls、對應的 role:"tool" 結果、最後的回答都在同一輪裡）。
# 超過預算就**整輪整輪**從最舊的丟，所以：
#   * system 永遠留著（它不屬於任何一輪）
#   * assistant 的 tool_calls 與它的 role:"tool" 訊息永遠一起走，不會拆散
#     （拆散了 OpenAI 相容端點會回 400：tool 訊息找不到對應的 tool_call_id）
#   * 最近 :min-turns 輪（預設 1）不管多大都留，不然連當前問題都送不出去
#
# ⚠ token 是**估的**：字元數 ÷ 4（英文大約準，中文一個字常常就是一個 token，會低估）。
#   它只拿來決定何時截斷，不是計費依據；真實用量看回應的 :usage。

(defn make-memory
  ``建一份空的記憶。
    :system     有給就先放一則 system 訊息
    :max-turns  最多留幾輪 user 對話，預設 20
    :max-chars  所有訊息內容加起來最多幾個字元（≈ token × 4），預設 48000（≈ 12k tokens）
    :min-turns  截斷時至少留幾輪，預設 1``
  [&named system max-turns max-chars min-turns]
  (default max-turns 20)
  (default max-chars 48000)
  (default min-turns 1)
  (def m @{:messages @[] :max-turns max-turns :max-chars max-chars :min-turns min-turns})
  (when (and system (not (empty? system)))
    (array/push (m :messages) @{:role "system" :content system}))
  m)

(defn messages
  "這份記憶的 messages 陣列（**同一個陣列**，不是複本；要送給 llm-http 直接丟這個）。"
  [m]
  (m :messages))

(defn system-of
  "system 訊息的內容；沒有回 nil。"
  [m]
  (def f (get (m :messages) 0))
  (when (and f (= "system" (get f :role))) (get f :content)))

(defn set-system!
  "換掉（或補上）system 訊息，永遠放在第 0 則。"
  [m text]
  (def msgs (m :messages))
  (if (system-of m)
    (put (msgs 0) :content text)
    (array/insert msgs 0 @{:role "system" :content text}))
  m)

(defn append!
  "接一則訊息到最後（不做任何檢查，訊息形狀由呼叫端負責）。"
  [m msg]
  (array/push (m :messages) msg)
  m)

(defn- content-chars
  "一則訊息大概佔幾個字元：content（字串或 parts 陣列）＋ tool_calls 的 arguments。"
  [msg]
  (def c (get msg :content))
  (var n (cond
           (bytes? c) (length c)
           (indexed? c) (sum (map |(length (string (get $ :text ""))) c))
           0))
  (when-let [calls (get msg :tool_calls)]
    (each call calls
      (+= n (length (string (get-in call [:function :arguments] ""))))))
  n)

(defn estimate-chars
  "所有訊息的字元總數。"
  [m]
  (sum (map content-chars (m :messages))))

(defn estimate-tokens
  "粗估 token 數 = 字元數 ÷ 4（⚠ 中文會低估，只拿來決定何時截斷）。"
  [m]
  (math/ceil (/ (estimate-chars m) 4)))

(defn turn-starts
  "每一輪的起點：所有 role=\"user\" 的索引。"
  [m]
  (seq [[i msg] :pairs (m :messages) :when (= "user" (get msg :role))] i))

(defn turn-count
  "目前有幾輪 user 對話。"
  [m]
  (length (turn-starts m)))

(defn trim!
  ``依 :max-turns 與 :max-chars 從最舊的整輪開始丟，回傳丟掉的訊息數。
  永遠留 system 與最近 :min-turns 輪。``
  [m]
  (var dropped 0)
  (while true
    (def starts (turn-starts m))
    (def over? (or (> (length starts) (m :max-turns))
                   (> (estimate-chars m) (m :max-chars))))
    (unless (and over? (> (length starts) (m :min-turns))) (break))
    # 丟第一輪：從 starts[0] 到 starts[1] 之前
    (def from (starts 0))
    (def to (starts 1))
    (def msgs (m :messages))
    (def kept (array/concat (array/slice msgs 0 from) (array/slice msgs to)))
    (+= dropped (- to from))
    (array/clear msgs)
    (array/concat msgs kept))
  dropped)

(defn clear!
  "清掉所有對話，只留 system。"
  [m]
  (def s (system-of m))
  (array/clear (m :messages))
  (when s (set-system! m s))
  m)
