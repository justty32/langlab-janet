# 需要 exec／run／daemon 這種「推機器動一下」的動作時，透過子行程呼叫 Python 原型
# `python3 <aos>/proto/aos.py …`。檔案協定（呼叫記錄、投遞、結果、狀態檔）不走這裡，
# 那是 call/deliver/inst 三支自己用 Janet 寫的。
#
# ★ stdout 用背景 fiber 邊跑邊讀（跟 pi-shell/proc.janet 同一個理由：輸出塞滿
#   pipe buffer 時「先 wait 再讀」會死鎖）。非 0 退出碼當**資料**回傳，不丟例外。

(import spork/json)
(import ./fsx)

(def default-proto "/home/lorkhan/repo/simple_tools/aos/proto/aos.py")

(defn proto-path
  "原型的位置：環境變數 AOS_PROTO 優先，否則用內建預設。"
  []
  (or (os/getenv "AOS_PROTO") default-proto))

(defn- drain [stream]
  (def buf @"")
  (ev/spawn (while true (def c (:read stream 4096)) (if (nil? c) (break)) (buffer/push buf c)))
  buf)

(defn aos-run
  ``跑一次 `python3 proto/aos.py <args…>`，回 @{:out … :err … :code …}。
  opts：:env 額外環境變數（table，字串鍵值），:cwd。``
  [args &opt opts]
  (default opts {})
  (def p (proto-path))
  (unless (fsx/exists? p)
    (errorf (string "找不到 aos 原型 %s。\n"
                    "下一步：設環境變數 AOS_PROTO 指到那支 aos.py，例如\n"
                    "  (os/setenv \"AOS_PROTO\" \"/path/to/aos/proto/aos.py\")") p))
  # ⚠ 兩個坑疊在一起，都會**靜默**失效（子行程原樣繼承舊環境，沒有任何錯誤）：
  #   ① os/spawn 的第三個參數**同時**是環境變數表與選項表：環境變數用**字串鍵**，
  #      :in／:out／:err 用 keyword 鍵，混在同一張表裡。寫成 {:env …} 沒有用。
  #   ② flags 一定要有 **:e**（`:pe`），否則整張表的環境變數被忽略。
  (def env (merge (os/environ) (or (opts :env) {}) {:out :pipe :err :pipe}))
  (def proc (os/spawn ["python3" p ;args] :pe env))
  (def out (drain (proc :out)))
  (def err (drain (proc :err)))
  (def code (os/proc-wait proc))
  @{:out (string out) :err (string err) :code code})

(defn aos-json
  "同 aos-run，但帶 --json 並把 stdout 解析成 table；解析不開就報錯（帶原始輸出指路）。"
  [args &opt opts]
  (def r (aos-run [;args "--json"] opts))
  (def [ok v] (protect (json/decode (r :out) true)))
  (unless ok
    (errorf "`aos %s --json` 的輸出不是 json（退出碼 %d）。\nstdout：%s\nstderr：%s"
            (string/join args " ") (r :code) (r :out) (r :err)))
  (put v :exit-code (r :code))
  (put v :stderr (r :err))
  v)

(defn run-land
  ``推一塊地走到閒著：`aos run <地> --until idle`。
  opts：:env、:budget、:timeout-ms。回傳 run 的報告 table。``
  [root &opt opts]
  (default opts {})
  (def args @["run" root "--until" "idle"])
  (when (opts :budget) (array/push args "--budget") (array/push args (string (opts :budget))))
  (when (opts :timeout-ms)
    (array/push args "--timeout") (array/push args (string (opts :timeout-ms))))
  (aos-json args opts))

(defn exec-once
  "讓一塊地走一格：`aos exec <地>`。回傳那一格的報告（含 :tick）。"
  [root &opt opts]
  (aos-json ["exec" root] opts))

(defn daemon
  ``看管者：(daemon :start)／(daemon :stop)／(daemon :ls)。
  脫節呼叫一定要它在（裁決 P-01），不然照 spec 直接 no_daemon 失敗。``
  [op &opt opts]
  (default opts {})
  (case op
    :start (aos-run ["daemon" "start" "--every" (string (or (opts :every-ms) 200))] opts)
    :stop  (aos-run ["daemon" "stop"] opts)
    :ls    (aos-json ["daemon" "ls"] opts)
    (errorf "不認得的 daemon 動作 %q，只有 :start／:stop／:ls" op)))
