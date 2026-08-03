#!/usr/bin/env janet
# 閉包：捕獲外層變數的函式。從最基本到幾個實用花招。
# 跑法：janet snippets/closures.janet
#
# 重點：
#   * 閉包捕獲的是「綁定」不是「當下的值」——捕 var 就看得到後續的改動
#   * def 捕獲不可變值；var 捕獲的是那個 :ref 盒子（所以能當私有狀態）
#   * |(...) 是 short-fn，$ 是第一個參數、$1 $2 是第二三個
#   * Janet 的閉包可以 marshal（連捕獲的狀態一起序列化）

(defn h [s] (printf "\n── %s" s))

# ── 1) 最基本：工廠函式 ──────────────────────────────────────────────
(h "工廠函式")
(defn adder [n]
  (fn [x] (+ x n)))          # n 被捕獲進回傳的函式裡
(def add5 (adder 5))
(def add100 (adder 100))
(printf "  (add5 10)=%d  (add100 10)=%d  兩個閉包各有各的 n" (add5 10) (add100 10))

# short-fn 版，同一件事
(defn adder* [n] |(+ $ n))
(printf "  short-fn 版：%d" ((adder* 7) 10))

# ── 2) 捕 var = 有私有狀態的物件 ─────────────────────────────────────
(h "私有可變狀態（counter）")
(defn make-counter [&opt start]
  (default start 0)
  (var n start)                       # 只有底下這幾個閉包看得到 n
  # ★ 用 (:inc c) 這種方法呼叫語法時，物件自己會被當第一個參數傳進來
  @{:inc   (fn [self &opt by] (+= n (or by 1)) n)
    :get   (fn [self] n)
    :reset (fn [self] (set n start) n)})
(def c (make-counter 10))
(:inc c) (:inc c 5)
(printf "  現在 = %d" (:get c))
(:reset c)
(printf "  reset 後 = %d，另開一個互不干擾 = %d" (:get c) (:get (make-counter)))

# ── 3) ★ 迴圈裡建閉包：Janet 每圈都是新綁定，不像 JS 的 var 坑 ────────
(h "迴圈裡建一堆閉包")
(def fs (seq [i :range [0 3]] (fn [] i)))
(printf "  各自記得自己的 i => %q" (map |($) fs))
# 但如果你刻意捕同一個 var，就會全部看到最後的值：
(var shared 0)
(def gs (seq [i :range [0 3]] (do (set shared i) (fn [] shared))))
(printf "  故意共用一個 var  => %q  ← 捕的是綁定不是值" (map |($) gs))

# ── 4) 記憶化（memoize）：閉包 + table ───────────────────────────────
(h "memoize")
(defn memoize [f]
  (def cache @{})
  (fn [& args]
    (def k (string/format "%j" args))          # 用參數的字串當 key
    (if (has-key? cache k)
      (cache k)
      (set (cache k) (f ;args)))))
(var calls 0)
(def slow-square (fn [x] (++ calls) (* x x)))
(def fast (memoize slow-square))
(fast 9) (fast 9) (fast 9)
(printf "  呼叫三次 (fast 9) => %d，底層只算了 %d 次" (fast 9) calls)

# ── 5) 一次性 / 節流 ─────────────────────────────────────────────────
(h "只准跑一次")
(defn once [f]
  (var done false)
  (var result nil)
  (fn [& args]
    (unless done (set result (f ;args)) (set done true))
    result))
(def init (once (fn [] (print "    真的初始化了") :ready)))
(init) (init) (init)
(printf "  結果 = %q（上面那行只印一次）" (init))

# ── 6) 部分套用 / 組合 ───────────────────────────────────────────────
(h "partial / comp")
(def add10 (partial + 10))
(printf "  (partial + 10) => %d" (add10 5))
(def 加十再平方 (comp |(* $ $) add10))
(printf "  (comp …) => %d" (加十再平方 5))

# ── 7) 閉包可以序列化，連捕獲的狀態一起 ──────────────────────────────
(h "marshal 一個閉包")
(def counter (make-counter 42))
(def bytes (marshal (counter :get)))
(printf "  存成 %d bytes，還原後仍記得 %d"
        (length bytes) ((unmarshal bytes) nil))

# ── 8) 閉包 vs 巨集：閉包在執行期、巨集在編譯期 ──────────────────────
(h "跟巨集的差別")
(defn 執行期 [x] (fn [] x))
(defmacro 編譯期 [x] ~(fn [] ,x))
(printf "  閉包 => %q" ((執行期 (+ 1 2))))
(printf "  巨集展開 => %q" (macex1 '(編譯期 (+ 1 2))))
(print "  能用閉包就別用巨集；巨集是「要看未求值的程式碼」時才出手。\n")
