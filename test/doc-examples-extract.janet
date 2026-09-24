# doc-examples 的「從 md 抽案例」那半：抽 ```janet 區塊、認案例行、整理預期值。
#
# ⚠ jpm test 會把 test/ 底下每一支 .janet 都當測試跑，所以這支只放定義，
#   單獨執行時零輸出、exit 0。主檔 doc-examples.janet 會 import 它。

(defn 剛好一個form?
  "src 是不是剛好 parse 出一個完整的 form（沒有殘留的未閉合括號／字串、沒有語法錯）。"
  [src]
  (def p (parser/new))
  (parser/consume p (string src "\n"))
  (var n 0)
  (while (parser/has-more p) (parser/produce p) (++ n))
  (and (nil? (parser/error p)) (= :root (parser/status p)) (= n 1)))

(defn 行案例
  ``認一行是不是「一個完整 form ＋ 空白 ＋ `# =>` ＋ 預期」，是就回 [form原文 預期原文]。
  不猜括號：從左到右試每個 `#`，把它前面那段交給 parser，剛好一個 form 才算。
  所以 `[1 2]`、`@{:a 1}`、`"abc"`、裸符號、數字開頭的行都認得到；
  字串裡的 `#`（前綴會卡在未閉合字串）與整行註解（前綴 parse 出零個 form）自然被排除。``
  [line]
  (var 結果 nil)
  (each i (string/find-all "#" line)
    (when (and (nil? 結果) (> i 0)
               (index-of (get line (dec i)) [(chr " ") (chr "\t")]))
      (def 後 (string/slice line (inc i)))
      (when-let [m (peg/match ~(* (any (set " \t")) "=>" (any " ") (<- (any 1))) 後)]
        (def 式 (string/trim (string/slice line 0 i)))
        (when (剛好一個form? 式) (set 結果 [式 (get m 0)])))))
  結果)

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

# 回傳 nil（文件寫的是它們**印出來**的東西），不比對回傳值
# ⚠ x 開頭那組（xprint/xprintf…）第一個參數是輸出目標，(with-dyns [*err* …]) 攔不到
#   直接寫 stderr 的那些，所以一併排除。
(def 印函式 ["printf" "pp" "print" "prin" "eprintf" "eprint" "eprin" "doc"
             "xprint" "xprintf" "xprin"])
(defn 印的? [式] (some |(string/has-prefix? (string "(" $) 式) 印函式))
