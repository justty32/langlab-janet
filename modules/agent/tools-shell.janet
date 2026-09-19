# run-command —— 讓模型跑一條指令。**預設不存在**：要 (shell-tool …) 明確建出來才有。
#
# 三道保險，全部可調：
#   :allow      指令前綴白名單（例如 ["ls" "git status" "cat"]）；nil＝不限（開了就全信）
#   :timeout    幾秒內跑不完就 kill，預設 10
#   :max-output stdout＋stderr 合計最多回多少字元，預設 4000
#
# ★ 不經過 shell：指令字串用空白切成 argv 直接 os/spawn。
#   所以 `ls; rm -rf /`、`a | b`、`> 檔案` 這些都**不會**被解釋（分號與管線只是普通參數），
#   白名單才擋得住；代價是引號也不會被解釋（"a b" 會變成兩個參數）。
# ⚠ 逾時的作法：os/proc-wait 丟在另一條 fiber、結果走 channel，主 fiber 用 ev/with-deadline
#   等 channel。**不能**直接 (ev/with-deadline n (os/proc-wait p))——deadline 到了之後
#   再 proc-wait 一次會撞 "cannot wait twice on a process"（實測）。

(import ./registry :as reg)

(def shell-timeout 10)
(def shell-max-output 4000)

(defn split-command
  "把指令字串用空白切成 argv（不處理引號）。"
  [cmd]
  (filter |(not (empty? $)) (string/split " " (string/trim (string cmd)))))

(defn allowed?
  ``指令有沒有落在白名單裡。比對「整段指令」的前綴，而且前綴後面要是結尾或空白，
  所以 allow 裡有 "ls" 時 "ls -la" 可以、"lsblk" 不行。allow 是 nil 就一律 true。``
  [allow cmd]
  (if (nil? allow)
    true
    (let [s (string/trim (string cmd))]
      (truthy?
        (some (fn [p]
                (and (string/has-prefix? p s)
                     (or (= (length p) (length s))
                         (= (chr " ") (get s (length p))))))
              allow)))))

(defn- drain [stream buf]
  (ev/spawn
    (while true
      (def chunk (:read stream 4096))
      (if (nil? chunk) (break))
      (buffer/push buf chunk))))

(defn run-command
  ``跑一條指令，回 @{:code 退出碼或 nil :out stdout :err stderr :timed-out? bool}。
  找不到執行檔會丟例外（訊息含指令名）。``
  [argv &named timeout]
  (default timeout shell-timeout)
  (def [ok proc] (protect (os/spawn argv :p {:out :pipe :err :pipe})))
  (unless ok (error (string "起不了指令 " (first argv) "：" proc)))
  (def out @"") (def err @"")
  (drain (proc :out) out)
  (drain (proc :err) err)
  (def ch (ev/chan 1))
  (ev/spawn (ev/give ch (os/proc-wait proc)))
  (def [done code] (protect (ev/with-deadline timeout (ev/take ch))))
  (unless done
    (os/proc-kill proc false :kill)
    (ev/take ch))                     # 收屍，不留殭屍行程
  (ev/sleep 0)                        # 讓 drain 把最後一段讀完
  @{:code (if done code nil) :out (string out) :err (string err) :timed-out? (not done)})

(defn- clip [s n]
  (if (<= (length s) n) s (string (string/slice s 0 n) "\n…（輸出已截斷，共 " (length s) " 字元）")))

(defn format-result
  "把 run-command 的結果排成模型看得懂的一段文字。"
  [r max-output]
  (def parts @[])
  (when (r :timed-out?) (array/push parts "⚠ 逾時被中止"))
  (array/push parts (string "exit code: " (or (r :code) "（無）")))
  (unless (empty? (r :out)) (array/push parts (string "stdout:\n" (r :out))))
  (unless (empty? (r :err)) (array/push parts (string "stderr:\n" (r :err))))
  (clip (string/join parts "\n") max-output))

(defn shell-tool
  ``建出 run-command 工具。不給 :allow 就是「什麼指令都能跑」——請想清楚再開。``
  [&named allow timeout max-output]
  (default timeout shell-timeout)
  (default max-output shell-max-output)
  (reg/make-tool "run-command"
    (string "在工作目錄執行一條指令（不經 shell：管線、重導向、引號都不會被解釋）。"
            (if allow (string "只允許以這些開頭：" (string/join allow "、")) ""))
    {:type "object"
     :properties {:command {:type "string" :description "要執行的指令，例如 \"ls -la\""}}
     :required ["command"]}
    (fn [args]
      (def cmd (string (get args :command "")))
      (def argv (split-command cmd))
      (when (empty? argv) (error "指令是空的"))
      (unless (allowed? allow cmd)
        (error (string "拒絕：「" cmd "」不在允許的指令清單裡（" (string/join allow "、") "）")))
      (format-result (run-command argv :timeout timeout) max-output))))
