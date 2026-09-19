# SSE 解析 ＋ OpenAI 串流片段的合併（純函式／閉包，不碰網路）。
#
# SSE 長這樣（一行一行來，事件之間空一行）：
#   data: {"choices":[{"delta":{"content":"你"}}]}
#   data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"f","arguments":"{\"a"}}]}}]}
#   data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"\":1}"}}]}}]}
#   data: {"choices":[{"delta":{},"finish_reason":"tool_calls"}]}
#   data: {"choices":[],"usage":{…}}          ← stream_options.include_usage 才有這塊
#   data: [DONE]
#
# 合併規則：content 片段字串接起來；tool_calls 依 **index** 分桶，id／name 第一塊才有、
# arguments 是分好幾塊的 JSON 字串要一路接；finish_reason 與 usage 取最後一次出現的。
# 合完的東西跟 chat 回的形狀一樣，reply-text／reply-message／with-tools 都直接吃。
#
# ⚠ `event:`／`: ping`／空行都不是資料，一律略過；只認 `data:` 開頭的行。
# ⚠ 一行裡的 \r 要剝掉（HTTP 那層的換行是 \r\n）。

(import spork/json)

(defn make-line-splitter
  ``把任意大小的 bytes 切成一行一行交給 on-line（不含換行、去掉尾端 \r）。
  回一個函式：餵 bytes 就切；餵 nil 表示結束，把最後沒換行的殘段也吐出去。``
  [on-line]
  (def pending @"")
  (fn feed [bytes]
    (if (nil? bytes)
      (do (unless (empty? pending) (on-line (string/trimr (string pending) "\r")))
          (buffer/clear pending))
      (do
        (buffer/push pending bytes)
        (var start 0)
        (while (< start (length pending))
          (def nl (string/find "\n" pending start))
          (if (nil? nl) (break))
          (on-line (string/trimr (string/slice pending start nl) "\r"))
          (set start (inc nl)))
        (when (pos? start)
          (def rest (string/slice pending start))
          (buffer/clear pending)
          (buffer/push pending rest))))))

(defn sse-data
  "「data: xxx」→ \"xxx\"；不是 data 行回 nil。"
  [line]
  (when (string/has-prefix? "data:" line)
    (string/trim (string/slice line 5))))

(defn make-sse-consumer
  ``回一個「吃一行」的函式：data 行解成 JSON 交給 on-event；[DONE] 之後什麼都不做。
  解不開的 data 行丟中文錯誤（伺服器回錯誤 JSON 時多半就是這裡看到）。``
  [on-event]
  (var done false)
  (fn consume [line]
    (unless done
      (when-let [d (sse-data line)]
        (if (= d "[DONE]")
          (set done true)
          (let [[ok v] (protect (json/decode d true))]
            (unless ok (error (string "SSE 的 data 不是合法 JSON：" d)))
            (on-event v)))))))

(defn make-openai-merger
  ``回 @{:feed (fn [chunk]) :finish (fn [])}：feed 吃一個 chat.completion.chunk，
  finish 把累積的片段組成一份跟 chat 同形狀的回應。on-delta（可省略）每收到一段 content 文字就叫一次。``
  [&opt on-delta]
  (def st @{:content @"" :calls @{} :finish nil :usage nil :id nil :model nil :n 0})
  (defn feed [chunk]
    (++ (st :n))
    (when-let [v (get chunk :id)]    (put st :id v))
    (when-let [v (get chunk :model)] (put st :model v))
    (when-let [u (get chunk :usage)] (put st :usage u))
    (when-let [choice (get-in chunk [:choices 0])]
      (when-let [fr (get choice :finish_reason)] (put st :finish fr))
      (def delta (get choice :delta))
      (when-let [t (get delta :content)]
        (when (and (string? t) (not (empty? t)))
          (buffer/push (st :content) t)
          (when on-delta (on-delta t))))
      (each tc (or (get delta :tool_calls) [])
        (def idx (or (get tc :index) 0))
        # ⚠ put 回的是整張表不是新值，所以先建 slot 再放進去
        (def slot (or (get (st :calls) idx)
                      (let [fresh @{:id nil :type "function" :function @{:name @"" :arguments @""}}]
                        (put (st :calls) idx fresh)
                        fresh)))
        (when-let [id (get tc :id)] (put slot :id id))
        (when-let [nm (get-in tc [:function :name])]
          (buffer/push (get-in slot [:function :name]) nm))
        (when-let [a (get-in tc [:function :arguments])]
          (buffer/push (get-in slot [:function :arguments]) a)))))
  (defn finish []
    (def calls (seq [i :in (sorted (keys (st :calls)))]
                 (def c (get (st :calls) i))
                 @{:id (c :id) :type "function"
                   :function @{:name (string (get-in c [:function :name]))
                               :arguments (string (get-in c [:function :arguments]))}}))
    (def text (string (st :content)))
    (def msg @{:role "assistant"
               :content (if (and (empty? text) (not (empty? calls))) nil text)})
    (unless (empty? calls) (put msg :tool_calls calls))
    (def out @{:id (st :id) :object "chat.completion" :model (st :model)
               :choices @[@{:index 0 :message msg :finish_reason (st :finish)}]
               :chunks (st :n)})
    (when (st :usage) (put out :usage (st :usage)))
    out)
  @{:feed feed :finish finish})
