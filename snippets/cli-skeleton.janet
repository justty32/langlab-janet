#!/usr/bin/env janet
# 一支真 CLI 工具的骨架——把各層接起來的那些「不寫就會缺」的東西。
# 跑法：
#   janet snippets/cli-skeleton.janet a.txt b.txt
#   janet snippets/cli-skeleton.janet -vv --upper a.txt      ← -vv 提高 log 等級
#   echo hi | janet snippets/cli-skeleton.janet -            ← 「-」讀 stdin（unix 慣例）
#   janet snippets/cli-skeleton.janet --help
#   janet snippets/cli-skeleton.janet --nope ; echo "exit=$?"
#
# 解析參數本身見 snippets/argv-parse.janet 與 docs/04；這支的重點是**接線**：
#   參數 → 設定 → 日誌 → 做事 → 錯誤處理 → exit code
# 每一段都標了「不寫會怎樣」。

(import spork/argparse :as ap)

# ── 1. exit code 先定義好 ─────────────────────────────────────
# 不定義的話你會到處寫 (os/exit 1)，之後想分辨「用法錯」與「執行失敗」就來不及了
(def EXIT-OK 0)
(def EXIT-失敗 1)
(def EXIT-用法錯 2)

# ── 2. 日誌：等級 ＋ 走 stderr ＋ 看 isatty 決定上色 ────────────
(def 等級 {:debug 0 :info 1 :warn 2 :error 3})
(var 門檻 (等級 :warn))
(def 上色? (os/isatty stderr))

(defn log [lv 格式 & 參數]
  ``⚠ 日誌一律走 stderr，不是 stdout。
  stdout 是「這支工具的產物」，要能乾淨地被 | 接走；
  混在一起的話下游 grep 到的東西就不對了。``
  (when (>= (等級 lv) 門檻)
    (def 前綴 (case lv :debug "debug" :info "info" :warn "warn" :error "error"))
    (def 著色 (case lv :error "31" :warn "33" :debug "2" "36"))
    (eprintf "%s %s"
             (if 上色? (string "\e[" 著色 "m" 前綴 "\e[0m") 前綴)
             (string/format 格式 ;參數))))

# ── 3. 參數 ──────────────────────────────────────────────────
(defn 解析 []
  ``回 nil 表示解析失敗（argparse 自己已經印過 usage 了）。
  ⚠ 四種 kind 只有 :flag :multi :option :accumulate——沒有 :count，
    寫錯會拿到 "unknown option kind"（docs/04）。``
  (ap/argparse
    "示範用的 CLI 骨架：把每個檔案的行數印出來"
    "verbose" {:kind :multi  :short "v" :help "多印一點，可疊加（-vv）"}
    "quiet"   {:kind :flag   :short "q" :help "只印錯誤"}
    "upper"   {:kind :flag   :short "u" :help "輸出轉大寫"}
    "output"  {:kind :option :short "o" :help "寫到檔案（預設 stdout）"}
    :default  {:kind :accumulate :help "要處理的檔案；「-」表示 stdin"}))

(defn 決定日誌等級 [opts]
  (cond
    (opts "quiet") (等級 :error)
    # -v → info、-vv 以上 → debug
    (let [v (or (opts "verbose") 0)]
      (cond (>= v 2) (等級 :debug)
            (>= v 1) (等級 :info)
            (等級 :warn)))))

# ── 4. 真正做事的部分：純函式，不碰 IO ─────────────────────────
# 這樣才測得動（見 docs/23）。IO 留在 main 那一層。
(defn 處理一份 [名稱 內容 &named 大寫]
  (def 行數 (length (string/split "\n" (string/trim 內容))))
  (def 摘要 (string/format "%s: %d 行" 名稱 行數))
  (if 大寫 (string/ascii-upper 摘要) 摘要))

# ── 5. IO 邊界 ───────────────────────────────────────────────
(defn 讀一份 [路徑]
  "「-」讀 stdin，是 unix 慣例；不支援的話你的工具就接不進管線。"
  (if (= "-" 路徑)
    [(string "<stdin>") (string (file/read stdin :all))]
    (do
      (unless (os/stat 路徑 :mode) (errorf "檔案不存在：%s" 路徑))
      [路徑 (slurp 路徑)])))

# ── 6. main：唯一一個知道 exit code 的地方 ─────────────────────
(defn main [&]
  (def opts (解析))
  (unless opts (os/exit EXIT-用法錯))      # argparse 已經印過 usage
  (set 門檻 (決定日誌等級 opts))

  (log :debug "解析結果：%j" (do (def o (table/clone opts)) (put o :order nil) o))

  # ⚠ spork/argparse 會**靜默吃掉單獨的 `-`**：它進不了 :default，也不報錯。
  #   所以 unix 的「- 代表 stdin」慣例得自己從原始 argv 撿回來
  #   （另一條路是叫使用者打 `-- -`，但沒人會想打那個）。
  (def 檔案 (array ;(or (opts :default) @[])))
  (when (and (empty? 檔案) (find |(= "-" $) (drop 1 (dyn :args))))
    (array/push 檔案 "-"))

  (when (empty? 檔案)
    (log :error "沒有給任何檔案。用 --help 看用法。")
    (os/exit EXIT-用法錯))

  # ⚠ 整包用 try 包起來，讓錯誤變成「一行人看得懂的訊息 ＋ 非 0 exit code」，
  #   而不是一坨 stacktrace。要看 stacktrace 才是 --debug 的事。
  (def 結果 @[])
  (var 有失敗? false)
  (each 路徑 檔案
    (try
      (let [[名 內容] (讀一份 路徑)]
        (log :info "處理 %s" 名)
        (array/push 結果 (處理一份 名 內容 :大寫 (opts "upper"))))
      ([e f]
        (set 有失敗? true)
        (log :error "%s" e)
        # 只有開了 debug 才給堆疊——一般使用者不需要看它
        (when (= 門檻 (等級 :debug)) (debug/stacktrace f e "")))))

  (def 輸出 (string (string/join 結果 "\n") "\n"))
  (if-let [檔 (opts "output")]
    (do (spit 檔 輸出) (log :info "已寫入 %s" 檔))
    (prin 輸出))                            # ⚠ 產物走 stdout

  # ⚠ 部分失敗也要回非 0，否則 shell 的 && 會誤以為全成功
  (os/exit (if 有失敗? EXIT-失敗 EXIT-OK)))
