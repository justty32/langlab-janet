#!/usr/bin/env janet
# 把一個集合「攤開」成函式的參數：[1 2 3] → (add 1 2 3)、{:a 1 :b 2} → (f :a 1 :b 2)。
# 跑法：janet snippets/apply-splice.janet
#
# 兩個工具，用途不同：
#   (apply f coll)   執行期：f 的最後一個參數位置攤開一個集合
#   ;coll            編譯期的 splice：可以攤在「任何位置」，也能用在資料字面裡
#
# 一句話：只有一個集合要攤在最後 → apply；其他情況 → ;

(defn h [s] (printf "\n── %s" s))

(defn add [& xs] (reduce + 0 xs))
(defn describe [&keys opts] opts)          # &keys = 收成一張 table
(defn named [&named host port] [host port]) # &named = 直接解構成具名參數

(defn main [&]
  # ── 1) array / tuple → 位置參數 ────────────────────────────────────
  (h "[1 2 3] → (add 1 2 3)")
  (def nums [1 2 3])
  (printf "  (apply add nums) => %q" (apply add nums))
  (printf "  (add ;nums)      => %q  ← ; 是 splice，編譯期攤開" (add ;nums))
  (printf "  @[] 也一樣       => %q" (add ;@[10 20 30]))

  (h "; 可以攤在任何位置，apply 只能攤最後")
  (printf "  (add 100 ;nums 200) => %q" (add 100 ;nums 200))
  (printf "  (apply add 100 nums) => %q  ← 前面照給、最後一個才是要攤的集合"
          (apply add 100 nums))
  (print "  ★ (apply add nums 100) 會把 100 當成「要攤開的集合」而炸掉")
  (let [[ok err] (protect (apply add nums 100))]
    (printf "     實測 => ok=%q err=%s" ok err))

  # ── 2) table / struct → 具名參數 ──────────────────────────────────
  (h "{:a 1 :b 2} → (f :a 1 :b 2)")
  (def opts {:a 1 :b 2})
  (print "  table/struct 不能直接 splice（它不是序列），要先攤平成 kv 陣列：")
  (printf "  (kvs opts)          => %q" (kvs opts))
  (printf "  (describe ;(kvs opts)) => %q" (describe ;(kvs opts)))
  (printf "  (apply describe (kvs opts)) => %q" (apply describe (kvs opts)))

  (h "&keys vs &named")
  (def conn {:host "localhost" :port 8080})
  (printf "  &keys  收成整張 table => %q" (describe ;(kvs conn)))
  (printf "  &named 解成具名參數   => %q" (named ;(kvs conn)))

  (h "kvs 的三個同伴")
  (printf "  (kvs t)   => %q  攤平成 [k v k v …]" (kvs opts))
  (printf "  (pairs t) => %q  成對" (pairs opts))
  (printf "  (keys t) (values t) => %q %q" (keys opts) (values opts))
  (print "  ★ table 沒有順序保證；要固定順序自己 sort")
  (printf "  排序過的 kvs => %q"
          (mapcat |[$ (opts $)] (sort (keys opts))))

  # ── 3) splice 在資料字面裡也能用 ───────────────────────────────────
  (h "; 不只用在呼叫，資料建構也吃")
  (printf "  [0 ;nums 4]     => %q" [0 ;nums 4])
  (printf "  @[;nums ;nums]  => %q" @[;nums ;nums])
  (print "  ★ {} 和 @{} 的「字面」不吃 splice——parser 在展開前就先數過項數了：")
  (printf "     {;(kvs opts) :c 3} => %q"
          (first (protect (eval-string "(def o {:a 1}) {;(kvs o) :c 3}"))))
  (print "     要攤就改用 struct / table 這兩個「函式」：")
  (printf "     (struct ;(kvs opts) :c 3)        => %q" (struct ;(kvs opts) :c 3))
  (printf "     (table ;(kvs opts) ;(kvs {:c 3})) => %q"
          (table ;(kvs opts) ;(kvs {:c 3}))) 

  # ── 4) 實用場景 ────────────────────────────────────────────────────
  (h "實用：組命令列參數")
  (def flags @["-l" "-a"])
  (def cmd ["ls" ;flags "/tmp"])
  (printf "  %q" cmd)
  (print "  → 直接丟給 (os/execute cmd :p)")

  (h "實用：把 table 當「具名參數包」傳來傳去")
  (defn 連線 [&named host port timeout]
    (default timeout 30)
    (string/format "連 %s:%d（timeout %d）" host port timeout))
  (def 設定 @{:host "example.com" :port 443})
  (printf "  %s" (連線 ;(kvs 設定)))
  (put 設定 :timeout 5)
  (printf "  %s" (連線 ;(kvs 設定)))

  (h "實用：轉發參數（wrapper 函式）")
  (defn 記錄一下 [f]
    (fn [& args]                     # 收下所有參數
      (printf "    呼叫 %q" args)
      (f ;args)))                    # 原樣轉發出去
  (def logged-add (記錄一下 add))
  (printf "  結果 => %q" (logged-add 1 2 3))

  # ── 5) 反過來：把參數收起來 ────────────────────────────────────────
  (h "反向：& 和 &keys 把參數收成集合")
  (printf "  (defn f [& xs])     收成 tuple  => %q" ((fn [& xs] xs) 1 2 3))
  (printf "  (defn f [&keys o])  收成 table  => %q" (describe :a 1 :b 2))
  (printf "  (defn f [a & rest]) 混著用      => %q"
          ((fn [a & rest] [a rest]) 1 2 3))

  (h "選哪個")
  (print "  (apply f coll)  ── 只有一個集合、而且就在最後 → 最直白")
  (print "  (f ;coll)       ── 要攤在中間、要攤多個、要用在 [] @[] 裡 → 只能用它")
  (print "                     （{} @{} 的字面不吃，改用 struct / table 函式）")
  (print "  table 要當參數 ── 先 (kvs t) 攤平，配 &keys 或 &named 接")
  (print))
