#!/usr/bin/env janet
# 把命令列參數轉成 table @{} 或 array @[]——自己手寫一版，再對照 spork/argparse。
# 跑法：
#   janet snippets/argv-parse.janet --name Alice -v --level=3 file1.txt file2.txt
#   janet snippets/argv-parse.janet -abc --tag x --tag y -- --這個不解析
#
# 重點：
#   * (dyn :args) 是完整的 argv，第 0 個是「腳本自己的路徑」
#   * (defn main [& args]) 拿到的也一樣，args[0] 是腳本名，真正的參數從 [1] 開始
#   * 取回來永遠是字串，要數字自己 scan-number
#   * 慣例：`--` 之後的東西不再當旗標解析，原樣留給下游

(import spork/argparse :as ap)

(defn h [s] (printf "\n── %s" s))

# ── 手工解析器 ───────────────────────────────────────────────────────
(defn parse-argv
  "把 argv 拆成 @{:flags @{} :positional @[] :rest @[]}。

  支援：--key value / --key=value / --flag / -abc（合併短旗標）/ -- 之後原樣保留。
  同一個 key 出現多次會自動變成陣列。"
  [argv]
  (def flags @{})
  (def positional @[])
  (def rest @[])
  (var i 0)
  (var stop false)

  (defn put-flag [k v]
    (def old (get flags k))
    (cond
      (nil? old)   (put flags k v)
      (array? old) (array/push old v)
      (put flags k @[old v])))       # 第二次出現才升級成陣列

  (while (< i (length argv))
    (def a (argv i))
    (cond
      stop                      (array/push rest a)
      (= a "--")                (set stop true)

      # --key=value
      (and (string/has-prefix? "--" a) (string/find "=" a))
      (let [idx (string/find "=" a)]
        (put-flag (keyword (slice a 2 idx)) (slice a (inc idx))))

      # --key value  或  --flag
      (string/has-prefix? "--" a)
      (let [k (keyword (slice a 2))
            next-a (get argv (inc i))]
        (if (and next-a (not (string/has-prefix? "-" next-a)))
          (do (put-flag k next-a) (++ i))
          (put-flag k true)))                 # 後面沒值 = 布林旗標

      # -abc  → -a -b -c
      (and (string/has-prefix? "-" a) (> (length a) 1))
      (let [chars (slice a 1)
            next-a (get argv (inc i))]
        (if (and (= 1 (length chars)) next-a (not (string/has-prefix? "-" next-a)))
          (do (put-flag (keyword chars) next-a) (++ i))
          (each c chars (put-flag (keyword (string/from-bytes c)) true))))

      (array/push positional a))
    (++ i))

  @{:flags flags :positional positional :rest rest})

# ── 幾個常用的後處理 ─────────────────────────────────────────────────
(defn flag-number
  "取一個旗標並轉成數字，沒有就用預設值。"
  [flags k &opt dflt]
  (if-let [v (get flags k)]
    (if (string? v) (scan-number v) v)
    dflt))

(defn flag-list
  "永遠拿到陣列——不管那個旗標出現一次還是多次。"
  [flags k]
  (def v (get flags k))
  (cond (nil? v) @[] (array? v) v @[v]))

(defn main [& args]
  # ★ args[0] 是腳本自己，真正的參數從 1 開始
  (var argv (slice args 1))

  (h "原始 argv")
  (printf "  (dyn :args) => %q" (dyn :args))
  (printf "  腳本自己    => %q" (args 0))
  (printf "  真正的參數  => %q" argv)

  (when (empty? argv)
    (print "\n（沒給參數，用一組示範的）")
    (set argv @["--name" "Alice" "-v" "--level=3" "--tag" "x" "--tag" "y"
                "file1.txt" "file2.txt" "--" "--原樣保留"]))

  (h "手工解析成 table")
  (def r (parse-argv argv))
  (printf "  :flags      => %q" (r :flags))
  (printf "  :positional => %q" (r :positional))
  (printf "  :rest       => %q  ← -- 之後原樣" (r :rest))

  (h "後處理")
  (printf "  level 轉數字   => %q（%q）"
          (flag-number (r :flags) :level 1) (type (flag-number (r :flags) :level 1)))
  (printf "  tag 一律當陣列 => %q" (flag-list (r :flags) :tag))
  (printf "  有沒有 -v      => %q" (truthy? (get-in r [:flags :v])))

  (h "轉成別的形狀")
  (printf "  只要位置參數的 array => %q" (r :positional))
  (printf "  攤平成 kv 陣列       => %q" (mapcat identity (pairs (r :flags))))
  (printf "  轉成不可變 struct    => %q"
          (struct ;(mapcat identity (pairs (r :flags)))))

  (h "對照組：spork/argparse")
  (print "  規則多、要自動 --help、要型別檢查 → 用 argparse（見 docs/04）")
  # argparse 讀 (dyn :args)，所以用 with-dyns 就能餵它任意一組參數來試
  (def demo ["--name" "Alice" "-v" "--level" "3" "--tag" "x" "--tag" "y" "f1" "f2"])
  (printf "  餵它 %q" demo)
  (def parsed
    (with-dyns [:args ["prog" ;demo]]
      (ap/argparse "示範"
                   "name"    {:kind :option :short "n"}
                   "level"   {:kind :option :map scan-number}  # ★ :map 直接轉型
                   "verbose" {:kind :flag :short "v"}          # ★ 短旗標要在這裡宣告
                   "tag"     {:kind :accumulate}
                   :default  {:kind :accumulate})))
  (if parsed
    (do
      (printf "  (parsed \"name\")    => %q" (parsed "name"))
      (printf "  (parsed \"level\")   => %q  ← :map scan-number 幫你轉好了" (parsed "level"))
      (printf "  (parsed \"verbose\") => %q" (parsed "verbose"))
      (printf "  (parsed \"tag\")     => %q" (parsed "tag"))
      (printf "  (parsed :default)  => %q  ← 位置參數" (parsed :default)))
    (print "  argparse 回 nil（參數不合規則或印過 help）"))

  (h "兩者的實際差異（都實測過）")
  (print "  ★ argparse 不吃 --key=value：`--level=3` 會噴 unknown option level=3")
  (print "  ★ 短旗標一定要在 spec 裡用 :short 宣告，臨時打 -v 不會通")
  (print "  ★ argparse 遇到不合規則會自己印 usage 並回 nil，手工版則是你自己決定怎麼辦")
  (print "  手工：規則簡單、不想多一個相依、要 --key=value、要完全掌控 -- 之後的東西")
  (print "  argparse：要 --help、要短/長旗標、要型別轉換與預設值")
  (print))
