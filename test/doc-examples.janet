# 防止教學腐化：把 docs/*.md 裡「(運算式)  # => 預期」的案例全部重跑一次。
#
# 為什麼要這支：鐵律 5 說「文件裡的輸出都是實測貼回來的」，但那只保證**寫的當下**
# 是對的。Janet 升版、spork 換版、或有人手改一個值，都會讓文件默默說謊。
#
# 做法：**逐 ```janet 區塊**求值——同一個區塊共用一個 env，所以前幾行 def 的東西
# 後面用得到（這是單行掃描做不到的，光靠單行會漏掉一半以上）。碰到 `# => 預期`
# 的那一行就比對 (string/format "%j" 結果) 與文件寫的字串。
#
# ⚠ 比的是 %j 的字面輸出，所以中文會被逃逸；這類案例列進「不比對」名單。

(import spork/json)
(import spork/misc)
(import spork/path)

(def 不比對
  {"02-資料結構.md:36"    "預期值後面只隔一個空白就接說明文字，切不乾淨"
   "02-資料結構.md:92"    "%j 逃逸中文，文件寫給人看的是對的"
   "19b-檔案系統與路徑.md:12" "需要當下不存在的 x.txt"
   "19b-檔案系統與路徑.md:13" "同上"
   "29-spork-資料與文字.md:123" "date/to-string 的結果隨今天日期而變"
   "29-spork-資料與文字.md:124" "同上"
   "32-條件與模式比對.md:73" "%j 逃逸中文"
   "32-條件與模式比對.md:74" "%j 逃逸中文"
   "40-內建動態變數.md:45"  "%j 逃逸中文"
   "03-json.md:48"         "回傳是 buffer，文件秀的是內容"
   "03-json.md:57"         "%j 逃逸中文"
   "16-marshal-與自省.md:51" "文件寫的是型別描述不是值"
   "16-marshal-與自省.md:52" "同上"
   "19b-檔案系統與路徑.md:32" "文件列的是所有可能值"
   "19b-檔案系統與路徑.md:51" "文件寫的是散文描述"
   "24-時間與日期.md:15"   "時間戳每次都不同"
   "24-時間與日期.md:89"   "文件寫的是散文描述"
   "26-隨機數.md:30"       "文件寫的是 print 的精度，%j 給全精度"
   "26-隨機數.md:99"       "密碼學亂數，每次都不同"
   "28b-spork-misc-文字與流程.md:65" "%j 逃逸中文"})

# 這些字樣一出現就整個區塊不跑：會動檔案系統、開子行程、或需要外部服務。
(def 危險 ["xprint" "os/execute" "os/spawn" "os/shell" "os/rm" "os/rmdir" "os/mkdir" "os/cd"
           "spit" "file/open" "file/temp" "net/" "http/" "sh/$" "os/exit" "os/sleep"
           # ⚠ ev/ 一定要排除：開了 ev/thread 或 ev/go 的區塊會讓**整個行程結束不了**
           #   （Janet 會等那些任務），症狀是測試跑完卻不退出，很難聯想。
           "ev/"])

(defn 危險區塊? [src] (some |(string/find $ src) 危險))

(def 行案例
  (peg/compile
    ~(* (any (set " \t")) (<- (* "(" (thru ")"))) (some (set " \t"))
        "#" (any (set " ")) "=>" (any (set " ")) (<- (any 1)))))

(defn 期望值
  "把 `# =>` 後面那串整理成待比對的字串；回 nil 表示這條不適合自動比對。"
  [raw]
  # 只切「兩個以上空白之後的說明文字」。
  # ⚠ 別想著「切到第一個中文字」——很多預期值本身就含中文（:兩格、"都不是"），
  #   那樣切會把正確的值切爛。只用一個空白分隔說明的那幾條，列進「不比對」名單。
  (def s (string/trim (first (string/split "  " raw))))
  (if (or (empty? s) (string/find "…" s)
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
  (def f (fiber/new (fn [] (set 結果 (with-dyns [*out* @"" *err* @""] (eval-string src)))) :e))
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

(each 檔 (filter |(string/has-suffix? ".md" $) (sort (os/dir "docs")))
  (each [起 src] (區塊們 (slurp (string "docs/" 檔)))
    (跑區塊 檔 起 src)))

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
