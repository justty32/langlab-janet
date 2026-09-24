# 防止教學腐化：把 docs/ 與 reference/ 裡「(運算式)  # => 預期」的案例全部重跑一次。
#
# 鐵律 5 說「文件裡的輸出都是實測貼回來的」，但那只保證**寫的當下**是對的——
# Janet 升版、spork 換版、或有人手改一個值，都會讓文件默默說謊。這支把它變成會變紅的測試。
#
# 做法：**逐 ```janet 區塊**求值，同一個區塊共用一個 env（前幾行 def 的東西後面用得到，
# 這是單行掃描做不到的）。碰到 `# => 預期` 就比對 (string/format "%j" 結果) 與文件寫的字串。
# ⚠ 比的是 %j 的字面輸出，所以中文會被逃逸；這類案例列進「不比對」名單。

(import spork/json)
(import spork/misc)
(import spork/path)

(import ./doc-examples-skip :as skip)
(def 不比對 skip/不比對)
(defn 危險區塊? [src] (skip/危險區塊? src))

# 運算式要括號平衡地抓：只抓到第一個 `)` 的話，`(+ (* 2 3) 1)  # => 7` 這種巢狀行
# 會默默不比對。字串字面裡的括號不算。
(def 行案例
  (peg/compile
    ~{:str (* "\"" (any (+ (* "\\" 1) (if-not "\"" 1))) "\"")
      :paren (* "(" (any (+ :str :paren (if-not (set "()") 1))) ")")
      :main (* (any (set " \t")) (<- :paren) (some (set " \t"))
               "#" (any (set " ")) "=>" (any (set " ")) (<- (any 1)))}))

(defn 期望值
  "把 `# =>` 後面那串整理成待比對的字串；回 nil 表示這條不適合自動比對。"
  [raw]
  # 切「兩個以上空白之後的說明文字」。
  # ⚠ 兩條試過但**不能用**的做法，寫下來免得下次又想試：
  #   1. 「切到第一個中文字」——很多預期值本身就含中文（:兩格、"都不是"），會切爛。
  #   2. 「先 parse 整串，成功就整串用」——parse 只取第一個值、不管後面還有沒有東西，
  #      所以 `:a   說明文字` 會被判定成「整串都是值」，反而更糟（實測從 182 掉到 81）。
  #   預期值本身含兩個空白的（json 縮排那條）就列進「不比對」名單。
  (def s (string/trim (first (string/split "  " raw))))
  # 「# => 印 hi」寫的是印出來的東西，不是回傳值。
  (if (or (empty? s) (string/find "…" s) (string/has-prefix? "印" s)
          (some |(string/find $ s) ["，" "。" "（" "「" "←" "⚠" "／"]))
    nil s))

(defn 區塊們
  "抽出 @[[起始行號 區塊原文] …]。"
  [文字]
  (def out @[]) (var 在內 false) (var 起 0) (def buf @[])
  (var n 0)
  (each line (string/split "\n" 文字)
    (++ n)
    (cond
      (and (not 在內) (string/has-prefix? "```janet" line)) (do (set 在內 true) (set 起 (inc n)) (array/clear buf))
      (and 在內 (string/has-prefix? "```" line)) (do (set 在內 false) (array/push out [起 (string/join buf "\n")]))
      在內 (array/push buf line)))
  out)

(var 相符 0) (var 不符 0) (var 跳過 0) (var 免驗 0)
(def 壞掉 @[])

# 回傳 nil（文件寫的是它們**印出來**的東西），不比對回傳值
# ⚠ x 開頭那組（xprint/xprintf…）第一個參數是輸出目標，(with-dyns [*err* …]) 攔不到
#   直接寫 stderr 的那些，所以一併排除。
(def 印函式 ["printf" "pp" "print" "prin" "eprintf" "eprint" "eprin" "doc"
             "xprint" "xprintf" "xprin"])
(defn 印的? [式] (some |(string/has-prefix? (string "(" $) 式) 印函式))

(defn 在env求值
  ``在指定的 env 裡求值一段原始碼，回 [成功? 值]。
  ⚠ 用 fiber/setenv 讓整個區塊共用一個 env（docs/12b），這樣前幾行 def 的東西
    後面才用得到。不能改成「每次重跑整段前綴」——那是 O(n²)，跑起來要好幾分鐘。``
  [src env]
  (var 結果 nil)
  (def f (fiber/new (fn [] (set 結果 (with-dyns [*out* @"" *err* @""] (eval-string src env)))) :e))
  (fiber/setenv f env)
  (def r (resume f))
  (if (= :error (fiber/status f)) [false r] [true 結果]))

(defn 跑區塊 [檔 起 src]
  (when (危險區塊? src) (break))
  # ⚠ 原型要給 (curenv) 不是預設的 root-env——否則區塊看不到本檔開頭 import 的
  #   spork/json、spork/misc、spork/path，用到它們的案例會全部變成「跳過」。
  (def env (make-env (curenv)))
  # ⚠ 逐行餵 parser 而不是逐行 eval——很多 form 是跨行寫的（defn、let、巨集），
  #   逐行 eval 會 parse 失敗而漏掉一大半。湊成完整 form 才求值。
  (def p (parser/new))
  (var n (dec 起))
  (var 最後值 nil)
  (var 最後ok false)
  (each line (string/split "\n" src)
    (++ n)
    # ⚠ 有些區塊**故意**放不合法的語法當反例（docs/08 那個把 `;` 當註解的）。
    #   parser 一出錯就不能再 consume，直接放棄這個區塊。
    (when (parser/error p) (break))
    (parser/consume p (string line "\n"))
    (when (parser/error p) (break))
    (while (parser/has-more p)
      (def form (parser/produce p))
      (def [ok v] (在env求值 (string/format "%j" form) env))
      (set 最後ok ok) (set 最後值 v))
    (when-let [caps (peg/match 行案例 line)]
      (def 式 (get caps 0))
      (def 鍵 (string 檔 ":" n))
      (def 期 (期望值 (get caps 1)))
      (cond
        (get 不比對 鍵) (++ 免驗)
        (or (nil? 期) (印的? 式) (not 最後ok)) (++ 跳過)
        (let [[ok2 印] (protect (string/format "%j" 最後值))]
          (cond
            (not ok2) (++ 跳過)
            (= 印 期) (++ 相符)
            (do (++ 不符) (array/push 壞掉 [鍵 式 期 印]))))))))

# docs/、reference/、course/ 都掃——reference 的 `# =>` 案例比 docs 還多，一樣會腐化。
(defn 掃目錄 [dir 前綴]
  (each 檔 (filter |(string/has-suffix? ".md" $) (sort (os/dir dir)))
    (each [起 src] (區塊們 (slurp (string dir "/" 檔)))
      (跑區塊 (string 前綴 檔) 起 src))))

(掃目錄 "docs" "")
(掃目錄 "reference" "reference/")
(掃目錄 "reference/spork" "reference/spork/")
(掃目錄 "course" "course/")

(each [鍵 式 期 實] 壞掉
  (eprintf "✘ %s\n    %s\n    文件寫 %s\n    實際   %s" 鍵 式 期 實))

(printf "docs 案例：相符 %d  不符 %d  跳過 %d  免驗 %d" 相符 不符 跳過 免驗)

(assert (zero? 不符)
        (string/format
          (string "有 %d 條教學裡的輸出跟實際不一樣（上面列出）。要嘛修文件，"
                  "要嘛——如果它本來就驗不了——加進本檔的「不比對」名單並寫明原因。")
          不符))
(assert (> 相符 150) (string/format "只核對到 %d 條，抽取器可能壞了" 相符))
(print "doc-examples 測試通過 ✓")
