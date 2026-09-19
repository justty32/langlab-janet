# trace —— 把 agent 每一步印成人看得懂的一行。預設寫 stderr，也可以換成寫檔。
#
# agent.janet 每一步會叫 (trace 事件)，事件是一張 table，:kind 有三種：
#   :model  打了一次模型   {:step n :ms 耗時 :finish-reason "stop"/"tool_calls"/… :tool-calls 幾個 :usage …}
#   :tool   執行了一個工具 {:step n :name "calc" :args {…} :result "…" :ms 耗時}
#   :done   這次 run 結束   {:steps n :stopped-by :done/:max-steps :usage 累計}
#
# 這支只做「事件 → 一行字」與「一行字 → 哪裡」，不認識 agent 的內部。
# ⚠ 印參數不用 %q：Janet 的 quoted 印法會把中文逃逸成 \xE5\x8F\xB0，看不懂。

(def result-limit
  "工具結果印到 stderr 時最多幾個 **bytes**，太長會弄髒終端。"
  200)

(defn fmt-args
  "參數表印成 k=v k=v；字串直接印本文，其他型別用 %q。"
  [args]
  (string/join
    (seq [[k v] :pairs (or args {})]
      (string/format "%s=%s" k (if (bytes? v) (string v) (string/format "%q" v))))
    " "))

(defn utf8-cut
  ``把字串切到最多 n 個 bytes，但**退回到 UTF-8 的字元邊界**，不會把一個中文字切一半。

  ⚠ 踩過：string/slice 與 length 都是以 **byte** 計的，一個中文字 3 bytes；
    直接切在 200 會剖開一個字，終端印出來是一個亂碼方塊（實測真的看到）。
    UTF-8 的接續 byte 是 0b10xxxxxx（0x80–0xBF），往回退到不是接續 byte 為止就對了。``
  [s n]
  (if (<= (length s) n)
    (string s)
    (do
      (var i n)
      (while (and (pos? i) (= 8r200 (band (get s i) 8r300))) (-- i))
      (string/slice s 0 i))))

(defn- one-line [s limit]
  (def flat (string/replace-all "\n" "⏎" (string s)))
  (if (> (length flat) limit) (string (utf8-cut flat limit) "…") flat))

(defn- fmt-usage [u]
  (if u
    (string/format "tokens=%d+%d"
                   (or (get u :prompt_tokens) (get u :prompt-tokens) 0)
                   (or (get u :completion_tokens) (get u :completion-tokens) 0))
    "tokens=?"))

(defn format-event
  "一個事件 → 一行字（沒有換行結尾）。不認識的 :kind 就整張 table 印出來。"
  [ev]
  (case (get ev :kind)
    :model (string/format "[步 %d] 模型 %.0fms finish=%s 要工具=%d %s"
                          (get ev :step 0) (get ev :ms 0)
                          (string (get ev :finish-reason "?"))
                          (get ev :tool-calls 0) (fmt-usage (get ev :usage)))
    :tool  (string/format "[步 %d] → %s(%s) %.0fms\n        ← %s"
                          (get ev :step 0) (get ev :name "?") (fmt-args (get ev :args))
                          (get ev :ms 0) (one-line (get ev :result "") result-limit))
    :done  (string/format "[完成] %d 步，停在 %s，%s"
                          (get ev :steps 0) (string (get ev :stopped-by "?"))
                          (fmt-usage (get ev :usage)))
    (string/format "%q" ev)))

(defn stderr-tracer
  "回一個 trace 函式：每個事件印一行到 stderr。"
  []
  (fn [ev] (eprint (format-event ev))))

(defn file-tracer
  "回一個 trace 函式：每個事件**追加**一行到 path（用 spit 的 :a 模式）。"
  [path]
  (fn [ev] (spit path (string (format-event ev) "\n") :a)))

(defn collect-tracer
  "回 [trace 函式, 事件陣列]：事件原樣收進陣列，測試與程式化分析用。"
  []
  (def events @[])
  [(fn [ev] (array/push events ev)) events])

(defn tee-tracer
  "把幾個 trace 函式合成一個（每個都會被叫到）。"
  [& fns]
  (fn [ev] (each f fns (f ev))))
