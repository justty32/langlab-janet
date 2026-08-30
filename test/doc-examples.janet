# 防止教學腐化：把 docs/*.md 裡「(運算式)  # => 預期」的單行案例全部重跑一次。
#
# 為什麼要這支：本 repo 的規矩是「文件裡的輸出都是實測貼回來的」（AGENTS.md 鐵律 5），
# 但那只保證**寫的當下**是對的。Janet 升版、spork 換版、或有人手改一個值，
# 都會讓文件默默說謊。這支把它變成 jpm test 的一部分。
#
# 做法：抽出行內符合 `(…)  # => 值` 的案例，eval 之後比對 (string/format "%j" 結果)
#      與文件寫的字串。⚠ 比的是 %j 的字面輸出，所以：
#        * 中文會被逃逸 → 這類案例列進「不比對」名單
#        * 預期寫的是散文描述（「以目前 cwd 展開的絕對路徑」）→ 同上
#        * 需要特定檔案／時間／亂數 → 同上

(import spork/json)
(import spork/misc)
(import spork/path)

(def docs-dir "docs")

# 這些案例**刻意不比對**，每一條都寫明原因。名單只准縮短不准隨便加長。
(def 不比對
  {"02-資料結構.md:92"          "%j 會逃逸中文，文件寫給人看的是對的"
   "03-json.md:48"               "回傳是 buffer，文件秀的是內容"
   "03-json.md:57"               "%j 會逃逸中文"
   "11-pipeline-signal.md:54"    "文件寫的是子行程印出來的東西，不是回傳值"
   "16-marshal-與自省.md:51"     "文件寫的是型別描述不是值"
   "16-marshal-與自省.md:52"     "同上"
   "19b-檔案系統與路徑.md:12"    "需要當下不存在的 x.txt"
   "19b-檔案系統與路徑.md:13"    "同上"
   "19b-檔案系統與路徑.md:28"    "結果隨 cwd 而異"
   "19b-檔案系統與路徑.md:32"    "文件列的是所有可能值"
   "19b-檔案系統與路徑.md:51"    "文件寫的是散文描述"
   "24-時間與日期.md:15"         "時間戳每次都不同"
   "24-時間與日期.md:89"         "文件寫的是散文描述"
   "26-隨機數.md:30"             "文件寫的是 print 的精度，%j 給全精度"
   "26-隨機數.md:99"             "密碼學亂數，每次都不同"
   "28b-spork-misc-文字與流程.md:65" "%j 會逃逸中文"})

# 這些開頭的運算式回傳 nil（文件寫的是它們**印出來**的東西），一律跳過
(def 印出來的 ["printf" "pp" "print" "prin" "eprintf" "eprint" "eprin" "file/write"])

# ⚠ 會開子行程的也跳過：子行程直接寫真的 fd，(with-dyns [*out* …]) 攔不到它，
#   測試輸出會被灌進外部命令的東西。而且 doc 測試本來就不該去跑外部命令。
(def 開子行程的 ["os/execute" "os/spawn" "os/shell" "sh/$"])

(defn 該跳過? [式]
  (some |(string/has-prefix? (string "(" $) 式) [;印出來的 ;開子行程的]))

(defn 抽案例
  "從一份 md 抽出 @[[行號 運算式 預期] …]。只認 ```janet 區塊裡的行。"
  [文字]
  (def out @[])
  (var 在區塊 false)
  (var 行號 0)
  (each line (string/split "\n" 文字)
    (++ 行號)
    (cond
      (string/has-prefix? "```" line) (set 在區塊 (string/has-prefix? "```janet" line))
      在區塊
      (when-let [caps (peg/match
                        ~(* (any (set " \t")) (<- (* "(" (thru ")")))
                            (some (set " \t")) "#" (any (set " ")) "=>" (any (set " "))
                            (<- (any 1)))
                        line)]
        (def [式 期] caps)
        # 預期若不像一個 Janet 值（散文、有中文標點、省略號）就跳過
        (def 期 (string/trim (first (string/split "  " 期))))
        (unless (or (empty? 期)
                    (string/find "…" 期)
                    (some |(string/find $ 期) ["，" "。" "（" "「" "←" "⚠"])
                    (該跳過? 式))
          (array/push out [行號 式 期])))))
  out)

(var 相符 0) (var 不符 0) (var 跳過 0) (var 免驗 0)
(def 壞掉 @[])

(each 檔 (filter |(string/has-suffix? ".md" $) (sort (os/dir docs-dir)))
  (each [行號 式 期] (抽案例 (slurp (string docs-dir "/" 檔)))
    (def 鍵 (string 檔 ":" 行號))
    (if (get 不比對 鍵)
      (++ 免驗)
      # ⚠ 有些案例自己會印東西——把輸出導進 buffer，否則測試輸出被灌爆。
      #   順序不能反：protect 是**用新 fiber 跑 body**，而 dyn 不會被新 fiber 繼承
      #   （docs/40 的範例就在證明這件事），所以 with-dyns 要放在 protect **裡面**。
      (let [[ok 值] (protect (with-dyns [*out* @"" *err* @""] (eval (parse 式))))]
        (if-not ok
          (++ 跳過)                                   # 需要上下文（前面幾行定義的變數）
          (let [[ok2 印] (protect (string/format "%j" 值))]
            (cond
              (not ok2)   (++ 跳過)
              (= 印 期)   (++ 相符)
              (do (++ 不符) (array/push 壞掉 [鍵 式 期 印])))))))))

(each [鍵 式 期 實] 壞掉
  (eprintf "✘ %s\n    %s\n    文件寫 %s\n    實際   %s" 鍵 式 期 實))

(printf "docs 單行案例：相符 %d  不符 %d  跳過(需上下文) %d  免驗(名單) %d"
        相符 不符 跳過 免驗)

(assert (zero? 不符)
        (string/format
          (string "有 %d 條教學裡的輸出跟實際跑出來的不一樣（上面列出）。"
                  "要嘛修文件，要嘛——如果它本來就驗不了——"
                  "加進本檔的「不比對」名單並寫明原因。")
          不符))
(assert (> 相符 150)
        (string/format "只核對到 %d 條（應該 150 條以上），抽取器可能壞了" 相符))
(print "doc-examples 測試通過 ✓")
