# 隨機數 —— 配合 docs/26-隨機數.md
#
# 跑法：janet examples/random-demo.janet
#
# 除了 math/random 與 os/cryptorand 那兩段，其餘都餵固定種子，
# 所以**每次跑輸出都一樣**——這正是本篇要示範的重點。

(defn 標題 [s] (print "\n─── " s " ───"))

# ── 1. 偽隨機 = 確定的數列 ────────────────────────────────────────────────
(標題 "1. 同種子 = 同結果")

(defn 抽五個 [seed]
  (def r (math/rng seed))
  (map (fn [_] (math/rng-int r 100)) (range 5)))

(printf "種子 42 第一次 => %q" (抽五個 42))
(printf "種子 42 第二次 => %q  ← 一模一樣" (抽五個 42))
(printf "種子 43       => %q  ← 換個種子就全變了" (抽五個 43))

# ── 2. 三種取數方法 ───────────────────────────────────────────────────────
(標題 "2. rng-int / rng-uniform / rng-buffer")

(def r (math/rng 2026))
(printf "(math/rng-int r 6)     => %q   0..5，⚠ 上限不含" (math/rng-int r 6))
(printf "(math/rng-int r)       => %q   不給上限 = 32-bit 範圍的正整數" (math/rng-int r))
(printf "(math/rng-uniform r)   => %q   [0,1) 的小數" (math/rng-uniform r))
(printf "(math/rng-buffer r 8)  => %q   八個隨機 byte" (math/rng-buffer r 8))

# ── 3. 擲骰子：驗證「上限不含」與分布 ─────────────────────────────────────
(標題 "3. 擲骰子 60000 次，看分布")

(defn 擲骰 [rng] (inc (math/rng-int rng 6)))

(def 骰 (math/rng 7))
(def 統計 (frequencies (map (fn [_] (擲骰 骰)) (range 60000))))
(each 點 (sort (keys 統計))
  (printf "  %d 點：%5d 次 (%.2f%%)" 點 (統計 點) (* 100 (/ (統計 點) 60000))))
(printf "  只出現 %q 這些點數 → 沒有 0 也沒有 7，inc 補對了"
        (sort (keys 統計)))

# ── 4. 洗牌：Fisher-Yates ─────────────────────────────────────────────────
(標題 "4. 洗牌")

(defn shuffle! [arr rng]
  (for i 0 (dec (length arr))
    (def j (+ i (math/rng-int rng (- (length arr) i))))   # 從 i..結尾 挑一個
    (def tmp (arr i))
    (put arr i (arr j))
    (put arr j tmp))
  arr)

(printf "原始   => %q" (array ;(range 10)))
(printf "洗過   => %q" (shuffle! (array ;(range 10)) (math/rng 2026)))
(printf "同種子 => %q  ← 可重現" (shuffle! (array ;(range 10)) (math/rng 2026)))

# 驗證均勻性：洗 60000 次，看「0 這張牌」落在每個位置的次數
(def 位置統計 (frequencies
                (seq [_ :range [0 60000]]
                  (find-index |(= 0 $) (shuffle! (array ;(range 10)) 骰)))))
(printf "0 這張牌落在各位置的次數（理想值各 6000）：")
(printf "  %q" (map |(位置統計 $) (range 10)))
(print "  ↑ 大致平均 = Fisher-Yates 是均勻的。")

# ── 5. 隨機 ID ────────────────────────────────────────────────────────────
(標題 "5. 隨機字串 / ID")

(defn hex-id [rng n]
  (string/join (map |(string/format "%02x" $) (math/rng-buffer rng n)) ""))

(printf "hex-id 種子 7  => %s" (hex-id (math/rng 7) 6))
(printf "hex-id 種子 7  => %s  ← 可重現，所以**不能當 token**" (hex-id (math/rng 7) 6))

# ── 6. 要安全的亂數 ───────────────────────────────────────────────────────
(標題 "6. os/cryptorand：不可重現，才安全")

(printf "(os/cryptorand 8) => %q" (os/cryptorand 8))
(printf "(os/cryptorand 8) => %q  ← 每次都不一樣，沒有種子可餵" (os/cryptorand 8))
(print "  密碼 / session token / salt 一律用這個；洗牌、模擬、測資用 math/rng。")

# ── 7. 全域那顆 ───────────────────────────────────────────────────────────
(標題 "7. math/random 與全域種子")

(printf "(math/random) => %q" (math/random))
(print "  ⚠ 這個值**每次跑這支程式都一樣**——Janet 不會自動用時間去種全域那顆。")
(print "     要每次不同得自己種：(math/seedrandom (os/time))")
(math/seedrandom 99)
(def a (map (fn [_] (math/random)) (range 3)))
(math/seedrandom 99)
(def b (map (fn [_] (math/random)) (range 3)))
(printf "seedrandom 99 兩次結果相同？ %q" (deep= a b))
(print "  ⚠ 但 seedrandom 動的是**全域**那顆，會影響整個程式——")
(print "    寫函式庫請用自己的 (math/rng seed)，不要碰它。")

(print "\n完。")
