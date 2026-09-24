# 防止教學腐化：把 docs/、reference/、course/ 裡「一個 form  # => 預期」的案例全部重跑一次。
#
# 鐵律 5 說「文件裡的輸出都是實測貼回來的」，但那只保證**寫的當下**是對的——
# Janet 升版、spork 換版、或有人手改一個值，都會讓文件默默說謊。這支把它變成會變紅的測試。
#
# 做法：**逐 ```janet 區塊**求值，同一個區塊共用一個 env（前幾行 def 的東西後面用得到，
# 這是單行掃描做不到的）。碰到 `# => 預期` 就比對 (string/format "%j" 結果) 與文件寫的字串。
# ⚠ 比的是 %j 的字面輸出，所以中文會被逃逸；這類案例列進「不比對」名單。
# 案例行不限 `(` 開頭：`[1 2]`、`@{…}`、`"字串"`、裸符號／數字開頭的行也抓
# （改成交給 parser 認「剛好一個 form」，見 doc-examples-extract 的「行案例」）。

(import spork/json)
(import spork/misc)
(import spork/path)

(import ./doc-examples-skip :as skip)
(use ./doc-examples-extract)
(def 不比對 skip/不比對)
(defn 危險區塊? [src] (skip/危險區塊? src))

(var 相符 0) (var 不符 0) (var 跳過 0) (var 免驗 0)
(def 壞掉 @[])

(defn 在env求值
  ``在指定的 env 裡求值一段原始碼，回 [成功? 值]。
  ⚠ 用 fiber/setenv 讓整個區塊共用一個 env（docs/12b），這樣前幾行 def 的東西
    後面才用得到。不能改成「每次重跑整段前綴」——那是 O(n²)，跑起來要好幾分鐘。
  ⚠ 輸出攔截要直接 put 進 env，不能包 (with-dyns …)：with-dyns 會開一個 env 是
    「以 env 為原型的新表」的 fiber，而 import 是寫進 (curenv)——於是區塊裡的
    (import …) 全寫進那張用完即丟的表，後面每行都 unknown symbol、默默算成跳過。``
  [src env]
  (var 結果 nil)
  (put env :out @"") (put env :err @"")
  (def f (fiber/new (fn [] (set 結果 (eval-string src env))) :e))
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
    (var 本行form 0)
    (while (parser/has-more p)
      (++ 本行form)
      (def form (parser/produce p))
      (def [ok v] (在env求值 (string/format "%j" form) env))
      (set 最後ok ok) (set 最後值 v))
    # ⚠ 案例行必須**剛好收尾一個頂層 form**：多行 form 內部的行（match 的分支、
    #   let 裡的一行）看起來也像案例，但那時最後值是上一個 form 的，比了只會亂報。
    (when-let [caps (and (pos? 本行form) (= :root (parser/status p)) (行案例 line))]
      (def 式 (get caps 0))
      (def 鍵 (string 檔 ":" n))
      (def 期 (期望值 (get caps 1)))
      (cond
        (get 不比對 鍵) (++ 免驗)
        (or (nil? 期) (印的? 式) (not 最後ok)) (++ 跳過)
        (let [[ok2 印] (protect (string/format "%j" 最後值))]
          (cond
            (not ok2) (++ 跳過)
            # 數字另外接受 %q：文件貼的是 REPL／pp 的 15 位印法（0.1、9.00719925474099e+15），
            # %j 卻印全精度（0.10000000000000001），兩者都算對。
            (or (= 印 期) (and (number? 最後值) (= 期 (string/format "%q" 最後值)))) (++ 相符)
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
