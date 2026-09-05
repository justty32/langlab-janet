# 「一個檔案＝一筆指令」那半（aos spec 04）。
# 一筆指令就是一次 POSIX 呼叫：argv 陣列、env、cwd、三條流是**檔案路徑**。
# 做法：包成 kind:"inst" 的投遞物投進某塊地的收件匣，推那塊地走一格，再讀執行結果檔。

(import spork/path)
(import ./fsx)
(import ./land :as L)
(import ./proc :as P)
(import ./deliver :as D)

(defn- scratch []
  # 沒指定投給誰時用 lib 自己的暫存區。⚠ 它一定要有一份 main.aos.json，
  # 否則 exec 會 parse_error、收件匣裡的指令永遠沒人跑（findings 第 3 條）。
  (L/workspace))

(defn inst
  ``把一筆指令投給一塊地、推它走一格、把執行結果讀回來。

  spec：{:argv ["/bin/echo" "hi"] :env {"K" "v"} :cwd "…" :land 投給誰
         :timeout-ms N :stdout 路徑 :stderr 路徑}
  回 @{:code 結束碼 :signal … :timed-out … :spawn-error … :out stdout 內容
       :err stderr 內容 :id 指令 id :land 那塊地 :result 執行結果檔路徑}

  ⚠ `:code` 是**傳輸層**的結束碼（跑沒跑起來），不是「做成沒做成」（spec S-04-29）。``
  [spec]
  (def argv (spec :argv))
  (unless (and (indexed? argv) (not (empty? argv)))
    (errorf "指令少了 argv，或 argv 不是非空陣列（S-04-04）。拿到的是 %q" argv))
  (def target (L/land (or (spec :land) (scratch))))
  (def id (fsx/new-id))
  (def body @{:format_version 1 :id id :argv (map string argv)})
  (when (spec :env) (put body :env (fsx/string-args (spec :env))))
  (when (spec :cwd) (put body :cwd (spec :cwd)))
  (when (spec :stdin) (put body :stdin (spec :stdin)))
  (when (spec :stdout) (put body :stdout (spec :stdout)))
  (when (spec :stderr) (put body :stderr (spec :stderr)))
  (when (spec :timeout-ms) (put body :timeout_ms (spec :timeout-ms)))
  (D/deliver! target (D/delivery :inst (L/root-of (L/workspace)) {:id id :inst body}))
  (def rep (P/exec-once (target :root)))
  (def tick (rep :tick))
  (when (nil? tick)
    (errorf "`aos exec %s` 沒回報格號（退出碼 %s）。stderr：%s"
            (target :root) (rep :exit-code) (rep :stderr)))
  (def rdir (path/join (target :ticks) (string tick) "results"))
  (def rfile (path/join rdir (string id ".json")))
  (def res (fsx/read-json rfile))
  (unless res
    (errorf (string "指令投進去了，但第 %d 格沒有它的執行結果檔 %s。\n"
                    "下一步：看 %s 的 .aos/inbox/rejected/ 有沒有被隔離的同 id 投遞物")
            tick rfile (target :root)))
  @{:id id
    :land (target :root)
    :result rfile
    :code (fsx/denull (res :exit_code))
    :signal (fsx/denull (res :signal))
    :timed-out (fsx/denull (res :timed_out))
    :spawn-error (fsx/denull (res :spawn_error))
    :out (if (fsx/exists? (fsx/denull (res :stdout))) (string (slurp (fsx/denull (res :stdout)))) "")
    :err (if (fsx/exists? (fsx/denull (res :stderr))) (string (slurp (fsx/denull (res :stderr)))) "")})

(defn exec-file
  ``把一個檔案（可執行檔或腳本）當一筆指令跑。這是「檔案當指令」的糖。

  (aos/exec-file "/bin/echo" "hi")
  (aos/exec-file "./build.sh" "--release" {:land "work/"})   # 最後一個 table 當選項``
  [p & argv]
  (def last-arg (last argv))
  (def opts (if (table? last-arg) last-arg (if (struct? last-arg) last-arg {})))
  (def rest (if (or (table? last-arg) (struct? last-arg)) (slice argv 0 -2) argv))
  (inst (merge {:argv [(string p) ;(map string rest)]} opts)))
