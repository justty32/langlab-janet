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

# 刻意不比對的案例，按原因分組。名單只准縮短，不准為了讓測試變綠而隨便加長。
(def 不比對
  (merge
    # ① %j 會把中文逃逸成 \xE4\xBD\xA0…，文件寫給人看的那個才是對的
    (tabseq [k :in ["02-資料結構.md:92" "03-json.md:57" "32-條件與模式比對.md:73"
                    "32-條件與模式比對.md:74" "40-內建動態變數.md:45"
                    "28b-spork-misc-文字與流程.md:65"]] k :逃逸中文)
    # ② 文件寫的是散文描述或所有可能值，不是單一個值
    (tabseq [k :in ["16-marshal-與自省.md:51" "16-marshal-與自省.md:52"
                    "19b-檔案系統與路徑.md:32" "19b-檔案系統與路徑.md:51"
                    "24-時間與日期.md:89" "03-json.md:48"]] k :散文)
    # ③ 結果本來就會變（時間、亂數、當下的檔案）
    (tabseq [k :in ["24-時間與日期.md:15" "26-隨機數.md:30" "26-隨機數.md:99"
                    "29-spork-資料與文字.md:123" "29-spork-資料與文字.md:124"
                    "19b-檔案系統與路徑.md:12" "19b-檔案系統與路徑.md:13"]] k :會變)
    # ④ 預期值本身含兩個空白，被說明文字的切法切爛（見「期望值」的註解）
    (tabseq [k :in ["02-資料結構.md:36" "reference/spork/資料格式與驗證.md:18"]] k :切不乾淨)))

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
  # 切「兩個以上空白之後的說明文字」。
  # ⚠ 兩條試過但**不能用**的做法，寫下來免得下次又想試：
  #   1. 「切到第一個中文字」——很多預期值本身就含中文（:兩格、"都不是"），會切爛。
  #   2. 「先 parse 整串，成功就整串用」——parse 只取第一個值、不管後面還有沒有東西，
  #      所以 `:a   說明文字` 會被判定成「整串都是值」，反而更糟（實測從 182 掉到 81）。
  #   預期值本身含兩個空白的（json 縮排那條）就列進「不比對」名單。
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

# docs/ 與 reference/ 都掃——reference 的 `# =>` 案例比 docs 還多，一樣會腐化。
(defn 掃目錄 [dir 前綴]
  (each 檔 (filter |(string/has-suffix? ".md" $) (sort (os/dir dir)))
    (each [起 src] (區塊們 (slurp (string dir "/" 檔)))
      (跑區塊 (string 前綴 檔) 起 src))))

(掃目錄 "docs" "")
(掃目錄 "reference" "reference/")
(掃目錄 "reference/spork" "reference/spork/")

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
