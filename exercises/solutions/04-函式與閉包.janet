# 練習 04 的參考解答
#
#   janet exercises/solutions/04-函式與閉包.janet

# 1. var 放在**工廠函式裡面**，所以每次呼叫工廠各得一份。
#    ⚠ 放到檔案層級就變成所有計數器共用同一個——這跟 docs/22 那個
#    「別把可變預設值放進 prototype」是同一個 bug 的兩種穿法（docs/33）。
(defn 做計數器 []
  (var n 0)
  (fn [] (++ n)))

# 2. ⚠ &opt 沒有預設值語法，省略就是 nil。要預設值配 default（docs/33）。
#    ⚠ default 看的是「值是不是 nil」，不是「有沒有傳」——明確傳 nil 也會被補掉。
(defn 帶預設 [x &opt y]
  (default y 10)
  [x y])

# 3. [& xs] 收成 **tuple**（不是 array）。空的時候是 ()，reduce 給初值 0 就對了。
(defn 總和 [& xs] (reduce + 0 xs))

# 4. ★ 這題的重點：閉包捕獲的是**綁定**不是值（docs/33）。
#    直接 (fn [] i) 的話三個閉包指向同一格 i，跑完全變成 3。
#    圈內 let 一份出來——那是新的綁定，每圈各一個。
#    （C++ 在迴圈裡寫 [&i] 再把 lambda 存起來，是一模一樣的 bug）
(defn 三個閉包 []
  (def out @[])
  (var i 0)
  (while (< i 3)
    (array/push out (let [這圈的 i] (fn [] 這圈的)))
    (++ i))
  out)

# 5. 閉包裡放一張 table 當快取。
#    ⚠ 快取的鍵要能比內容——參數是 array 的話得先 freeze（docs/35）。
#    這裡參數是數字，直接當鍵沒問題。
(defn memoize [f]
  (def 快取 @{})
  (def 次數 @{:算過幾次 0})
  [(fn [x]
     (if (has-key? 快取 x)
       (get 快取 x)
       (do
         (update 次數 :算過幾次 inc)
         (put 快取 x (f x))
         (get 快取 x))))
   次數])

# 6. &named 各自綁成變數，沒給就是 nil——所以用 nil 判斷「有沒有給」。
#    ⚠ 這裡不能用 default 判斷「有沒有給 port」再決定協定，因為要同時決定兩件事。
(defn 組網址 [&named host port]
  (if port
    (string "http://" host ":" port)
    (string "https://" host ":443")))

# ── 檢查 ──────────────────────────────────────────────────────

(var 過 0) (var 錯 0)
(defn 檢查 [n 說明 實得 預期]
  (if (deep= 實得 預期)
    (++ 過)
    (do (++ 錯) (printf "✘ 第 %d 題：%s\n    預期 %j\n    實得 %j" n 說明 預期 實得))))

(def c1 (做計數器))
(def c2 (做計數器))
(檢查 1 "兩個獨立的計數器" [(c1) (c1) (c1) (c2)] [1 2 3 1])
(檢查 2 "&opt 配 default" [(帶預設 1) (帶預設 1 2)] [[1 10] [1 2]])
(檢查 3 "可變參數總和" [(總和) (總和 1 2 3)] [0 6])
(檢查 4 "迴圈裡的三個閉包" (map |($) (三個閉包)) @[0 1 2])

(def [快取版 次數] (memoize (fn [x] (* x x))))
(檢查 5 "memoize"
       [(快取版 4) (快取版 4) (快取版 5) (get 次數 :算過幾次)]
       [16 16 25 2])

(檢查 6 "具名參數組網址"
       [(組網址 :host "x" :port 80) (組網址 :host "y")]
       ["http://x:80" "https://y:443"])

(printf "\n過 %d 題，錯 %d 題" 過 錯)
(assert (zero? 錯) "參考解答自己沒過——那就是解答寫錯了")
(print "✓ 參考解答全部通過")
