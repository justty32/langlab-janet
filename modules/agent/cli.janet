# CLI 主流程 —— 從旗標組出 agent、問一句或進互動模式。也是 CLI 這層的門面。
#
# 能純函式化的（endpoint-of／build-tools／agent-opts）都拆出來，測試不用 os/exit 也叫得到；
# 只有 run 會印東西與 os/exit。
# ★ 輸出約定：stdout 只放答案本文，trace／提示／錯誤一律 stderr。

(import ./cli-flags :prefix "" :export true)
(import ../llm-http/init :as llm)
(import ./presets)
(import ./memory-io)
(import ./trace)
(import ./agent)

(defn- die [fmt & args]
  (eprint (string/format fmt ;args))
  (os/exit 1))

(defn- num-or-die [res key]
  (when-let [s (res key)]
    (or (scan-number s) (die "--%s 要是數字，收到：%s" key s))))

(defn endpoint-of
  "從旗標組 endpoint 設定：名字＋（可省略的）--model／--base／--url 覆寫。找不到名字回 nil。"
  [res]
  (def ov @{})
  (when-let [m (res "model")] (put ov :model m))
  (when-let [b (res "base")]  (put ov :base b))
  (when-let [u (res "url")]   (put ov :url u))
  (llm/endpoint (res "endpoint") ov))

(defn build-tools
  "從旗標組工具陣列：--root／--allow-write／--allow-shell／--shell-allow／--no-http。"
  [res]
  (presets/default-tools :root (res "root")
                         :write? (res "allow-write")
                         :shell (res "allow-shell")
                         :shell-allow (res "shell-allow")
                         :http? (not (res "no-http"))))

(defn tracer-of
  "-v → stderr；--trace-file → 追加寫檔；兩個都有就都做；都沒有回 nil。"
  [res]
  (def fns @[])
  (when (res "verbose")    (array/push fns (trace/stderr-tracer)))
  (when (res "trace-file") (array/push fns (trace/file-tracer (res "trace-file"))))
  (case (length fns) 0 nil 1 (fns 0) (trace/tee-tracer ;fns)))

(defn agent-opts
  "旗標 → make-agent 的 opts（endpoint 已 resolve、tools 已組好、--resume 已讀回）。"
  [res]
  (def cfg (endpoint-of res))
  (unless cfg
    (error (string "沒有這個 endpoint：" (res "endpoint")
                   "（可用：" (string/join (llm/endpoint-names) "、") "）")))
  @{:endpoint cfg
    :system (res "system")
    :tools (build-tools res)
    :max-steps (or (num-or-die res "max-steps") 10)
    :trace (tracer-of res)
    :memory (when-let [p (res "resume")] (memory-io/load p))
    :temperature (num-or-die res "temperature")
    :max-tokens (num-or-die res "max-tokens")})

(defn- answer-line [out]
  (or (out :text)
      (string/format "（打滿 %d 步模型還在要工具，沒有最終答案）" (out :steps))))

(defn- ask!
  "問一句、印答案、有 --save 就存。失敗回 false（訊息已印到 stderr）。"
  [ag res question &opt images]
  (def [ok out] (protect (agent/run ag question :images images)))
  (if ok
    (do (print (answer-line out))
        (flush)
        (when-let [p (res "save")] (memory-io/save! (ag :memory) p)))
    (do (flush) (eprintf "呼叫失敗：%s" out)))
  ok)

(defn- interactive!
  "一行一問，/quit 離開；stdin EOF 也離開。"
  [ag res]
  (eprint "互動模式：一行一問，/quit 離開。")
  (var first true)
  (while true
    (when (os/isatty stdin) (eprin "> ") (flush stderr))
    (def line (file/read stdin :line))
    (when (nil? line) (break))
    (def q (string/trim line))
    (cond
      (= q "/quit") (break)
      (empty? q) nil
      (do (ask! ag res q (when first (res "image")))
          (set first false)))))

(defn run
  "CLI 主流程。argv 第 0 個是執行檔自己。會 os/exit，測試請叫上面的純函式。"
  [argv]
  (def res (parse-args argv))
  (unless res (os/exit 1))
  (def [ok opts] (protect (agent-opts res)))
  (unless ok (die "%s" opts))
  (def [ok2 ag] (protect (agent/make-agent opts)))
  (unless ok2 (die "%s" ag))
  (def words (or (res :default) @[]))
  (if (or (res "interactive") (empty? words))
    (interactive! ag res)
    (unless (ask! ag res (string/join words " ") (res "image"))
      (os/exit 1))))
