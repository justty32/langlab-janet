#!/usr/bin/env janet
# 載入設定：預設值 → 設定檔 → 環境變數 → 命令列，一層層蓋上去，最後驗證形狀。
# 跑法：janet snippets/config-load.janet
#       PORT=9999 janet snippets/config-load.janet      ← 看環境變數蓋掉設定檔
#
# 重點：
#   * 設定檔用 .jdn（Janet 資料字面值）而不是 JSON——註解、keyword、多行字串都能寫
#   * ⚠ 讀設定檔只 parse 不 eval：eval 等於讓設定檔執行任意程式碼
#   * 覆蓋順序要**明確寫出來**，不然半年後沒人知道誰蓋誰
#   * 驗證用 spork/schema，⚠ 它的 quote 坑見 docs/29

(import spork/schema)

# ── 1. 預設值（不可變，當常數表）──────────────────────────────
# ⚠ 用 {} 不用 @{}：不可變字面值是編譯期常數，完全免費（見 docs/37）
(def 預設
  {:host "127.0.0.1"
   :port 4000
   :timeout 30
   :log-level :info})

# ── 2. 設定檔：只 parse 不 eval ───────────────────────────────
(defn 讀設定檔
  ``讀一份 .jdn 設定檔。檔案不存在回 nil（那不是錯誤，是「沒設定」）。

  ⚠ 用 parse 不用 eval——設定檔不該能執行程式碼。
  parse 只認得資料字面值：@{} [] "字串" :keyword 123 true nil。``
  [路徑]
  (when (os/stat 路徑 :mode)
    (def 原文 (slurp 路徑))
    (try
      (parse 原文)
      ([e] (errorf "設定檔 %s 讀不動：%s" 路徑 e)))))

# ── 3. 環境變數 ──────────────────────────────────────────────
# 一張表講清楚「哪個環境變數對應哪個欄位、怎麼轉型」，別散在程式各處
(def env對照
  [["HOST"      :host      identity]
   ["PORT"      :port      scan-number]
   ["TIMEOUT"   :timeout   scan-number]
   ["LOG_LEVEL" :log-level keyword]])

(defn 從環境變數 []
  (def out @{})
  (each [名 鍵 轉] env對照
    (when-let [v (os/getenv 名)]
      (def 轉好 (轉 v))
      # ⚠ scan-number 失敗回 nil 不拋錯——自己擋，否則會把 :port 設成 nil
      (if (nil? 轉好)
        (errorf "環境變數 %s=%q 轉不了型" 名 v)
        (put out 鍵 轉好))))
  out)

# ── 4. 合併：後面蓋前面 ───────────────────────────────────────
(defn 合併 [& 層]
  "後面的蓋前面的。⚠ merge 一律回 table，即使餵進去的全是 struct（docs/35b）。"
  (merge ;(filter truthy? 層)))

# ── 5. 驗證形狀 ──────────────────────────────────────────────
# ⚠ 一定要用 (props …)：裸 struct 不是逐欄位驗證，它會拿整包去 = 比較（docs/29）
(def 合法?
  (schema/predicate
    (props :host      :string
           :port      :number
           :timeout   :number
           :log-level (enum :debug :info :warn :error))))

(def 說明錯在哪
  (schema/validator
    (props :host      :string
           :port      :number
           :timeout   :number
           :log-level (enum :debug :info :warn :error))))

(defn 載入
  ``完整流程。覆蓋順序（後面蓋前面）：
     預設值 → 設定檔 → 環境變數 → 呼叫端傳進來的``
  [&named 設定檔 覆寫]
  (def cfg (合併 預設 (when 設定檔 (讀設定檔 設定檔)) (從環境變數) 覆寫))
  (unless (合法? cfg)
    # validator 會說清楚是哪一欄、期望什麼、拿到什麼
    (try (說明錯在哪 cfg) ([e] (errorf "設定不合法：%s" e))))
  cfg)

# ── 示範 ─────────────────────────────────────────────────────
(defn main [&]
  (def 暫存 (string (os/getenv "TMPDIR" "/tmp") "/janet-config-demo.jdn"))
  (spit 暫存 `@{:port 5000 :log-level :debug}`)

  (print "\n── 一層層蓋上去 ──────────────────")
  (printf "  ① 預設值        %j" 預設)
  (printf "  ② 設定檔        %j" (讀設定檔 暫存))
  (printf "  ③ 環境變數      %j  %s" (從環境變數)
          (if (empty? (從環境變數)) "（試試 PORT=9999 janet …）" ""))
  (printf "  ④ 呼叫端覆寫    %j" {:timeout 5})
  (printf "  ＝ 合併結果     %j" (載入 :設定檔 暫存 :覆寫 {:timeout 5}))

  (print "\n── 設定檔不存在不是錯誤 ──────────────────")
  (printf "  %j" (讀設定檔 "/絕對沒有這個檔.jdn"))

  (print "\n── ⚠ 只 parse 不 eval：設定檔不能執行程式碼 ──────────────────")
  (spit 暫存 `@{:port (os/shell "echo 我被執行了")}`)
  (def 危險 (讀設定檔 暫存))
  (printf "  讀到的 :port => %j  型別 %j" (危險 :port) (type (危險 :port)))
  (print "  ↑ 它是一個「沒有人執行的 tuple」，不是命令的結果——這正是我們要的")
  (printf "  但它過不了驗證：%s"
          (try (do (載入 :設定檔 暫存) "居然過了") ([e] (string e))))

  (print "\n── 驗證抓得到什麼 ──────────────────")
  (each [說明 壞的] [["port 是字串" {:port "5000"}]
                     ["log-level 不在列舉裡" {:log-level :verbose}]
                     ["缺 host" nil]]
    (def cfg (if 壞的 (合併 預設 壞的) (merge {} {:port 1 :timeout 1 :log-level :info})))
    (printf "  %-22s => %s" 說明
            (try (do (說明錯在哪 cfg) "通過") ([e] (string e)))))

  (os/rm 暫存)
  (print "\n✓ config-load 跑完"))
