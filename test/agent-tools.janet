# agent：工具箱（registry）、calc、now。純函式，不打網路、不碰檔案。

(import ../modules/agent/init :as ag)
(import ./util :as u)

# ── make-tool／deftool 的驗證 ───────────────────────────────────────
(def schema {:type "object" :properties {:x {:type "number"}} :required ["x"]})
(assert (string/find "只能用英數字" (u/err-of |(ag/make-tool "中文名" "d" schema (fn [_] 1)))))
(assert (string/find "JSON schema" (u/err-of |(ag/make-tool "ok" "d" "不是表" (fn [_] 1)))))
(assert (string/find "handler 必須是函式" (u/err-of |(ag/make-tool "ok" "d" schema 42))))

(ag/deftool double "把數字乘二" schema [args] (* 2 (get args :x 0)))
(assert (ag/tool? double) "deftool 做出來的是工具 table")
(assert (= "double" (double :name)) "工具名就是符號名")
(assert (= "把數字乘二" (double :description)))

# ── registry：陣列與 table 兩種形狀都收 ─────────────────────────────
(def reg (ag/make-registry double))
(ag/register-tool! reg ag/calc-tool)
(assert (deep= @["calc" "double"] (ag/tool-names reg)) "名字排序過")
(assert (deep= (ag/tool-names reg) (ag/tool-names [double ag/calc-tool])) "陣列與 table 等價")
(assert (string/find "不是工具 table" (u/err-of |(ag/as-table [@{:name "x"}]))))
(assert (string/find "只收 make-tool" (u/err-of |(ag/register-tool! reg @{:name "x"}))))

# ── 轉成 llm-http 的形狀 ────────────────────────────────────────────
(def specs (ag/tools->specs reg))
(assert (= 2 (length specs)))
(assert (= "function" (get-in specs [0 :type])) "就是 llm-http 的 tool-spec")
(assert (= "calc" (get-in specs [0 :function :name])))
(assert (= "double" (get-in specs [1 :function :name])))
(assert (deep= schema (get-in specs [1 :function :parameters])) "schema 原樣送出")
(def handlers (ag/tools->handlers reg))
(assert (= 14 ((handlers "double") @{:x 7})) "handlers 表是名字 → 函式")

# ── call-tool：一定回字串；例外變錯誤字串（跟 llm-http/with-tools 一致）──
(assert (= "14" (ag/call-tool reg "double" @{:x 7})) "數字結果會 encode 成 JSON 字串")
(assert (= "14" (ag/call-tool reg "double" `{"x":7}`)) "args 給 JSON 字串也可以")
(assert (= "0" (ag/call-tool reg "double" "這不是 JSON")) "解不開的 args 當空 table")
(assert (= "錯誤：沒有名為 nope 的工具" (ag/call-tool reg "nope" @{})))
(ag/deftool boom "一定壞" {:type "object" :properties {}} [_] (error "壞掉了"))
(assert (= "工具執行失敗：壞掉了" (ag/call-tool [boom] "boom" @{})) "handler 丟例外 → 錯誤字串，不炸")
(ag/deftool tbl "回 table" {:type "object" :properties {}} [_] {:a 1})
(assert (= `{"a":1}` (ag/call-tool [tbl] "tbl" @{})) "非字串結果 encode 成 JSON")

# ── calc：PEG 解析，不是 eval ───────────────────────────────────────
(assert (= 7 (ag/calc "1+2*3")))
(assert (= 9 (ag/calc "(1+2)*3")))
(assert (= 2.5 (ag/calc "10/4")))
(assert (= 1024 (ag/calc "2^10")))
(assert (= 5 (ag/calc "3 - -2")))
(assert (= 1 (ag/calc "7 % 3")))
(assert (= -6 (ag/calc "-3*2")))
(assert (string/find "除以零" (u/err-of |(ag/calc "1/0"))))
(assert (string/find "算式看不懂" (u/err-of |(ag/calc "1+"))))
(assert (string/find "算式看不懂" (u/err-of |(ag/calc "(os/exit 1)"))) "塞程式碼進來只會得到看不懂")
(assert (string/find "算式看不懂" (u/err-of |(ag/calc "abc"))))
(assert (= "7" (ag/call-tool [ag/calc-tool] "calc" @{:expression "1+2*3"})) "整數印成整數，不是 7.0")
(assert (= "2.5" (ag/call-tool [ag/calc-tool] "calc" @{:expression "5/2"})))
(assert (string/has-prefix? "工具執行失敗：算式看不懂" (ag/call-tool [ag/calc-tool] "calc" @{:expression "x"})))

# ── now ──────────────────────────────────────────────────────────────
(def t (ag/call-tool [ag/now-tool] "now" @{}))
(assert (peg/match ~(* :d :d :d :d "-" :d :d "-" :d :d "T" :d :d ":" :d :d ":" :d :d "Z" -1) t)
        (string "now 要是 ISO 8601：" t))

(print "agent 工具箱／calc／now 測試通過 ✓")
