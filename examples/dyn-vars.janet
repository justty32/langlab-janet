# 配合 docs/40-內建動態變數.md
#
#   janet examples/dyn-vars.janet 引數A 引數B
#
# 帶幾個引數跑，才看得到 *args* 的效果。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-32s => %j" 說明 結果))

(節 "*out* 不是變數，它就是 keyword :out")
(秀 "*out*" *out*)
(秀 "*err*" *err*)
(秀 "(= (dyn *out*) (dyn :out))" (= (dyn *out*) (dyn :out)))
(print "  env 裡那筆綁定長這樣（節錄）：")
(def 綁定 (get root-env '*out*))
(printf "    :dyn %j  :value %j" (綁定 :dyn) (綁定 :value))
(printf "    :doc %s" (綁定 :doc))

(節 "為什麼要多這一層：打錯名字會被擋下來")
(秀 "(dyn :ouy)  裸 keyword 打錯" (dyn :ouy))
(print "    ↑ 靜默回 nil，沒有人會告訴你打錯了")
(def r (compile '(dyn *ouy*) (curenv)))
(printf "  %-32s => %s" "(dyn *ouy*) 星號版打錯"
        (if (table? r) (r :error) "（沒擋住）"))
(print "    ↑ 編譯期就擋下來，而且 (doc *out*) 查得到說明")

(節 "把印出來的東西接進 buffer —— *out* 最常見的用途")
(def b @"")
(with-dyns [*out* b] (print "這行去了 buffer") (printf "%d 也是" 42))
(printf "  buffer 收到 => %s" (string/replace-all "\n" "⏎" (string b)))
(print "  spork/test 的 capture-stdout、temple 的渲染，底下都是這一招")

(def eb @"")
(with-dyns [*err* eb] (eprint "錯誤輸出也能導"))
(printf "  *err* 導向 buffer => %s" (string/replace-all "\n" "⏎" (string eb)))

(節 "這支程式的執行環境")
(秀 "(dyn *args*)" (dyn *args*))
(print "    ↑ 第 0 格是腳本名，跟 C 的 argv 一樣；這是原始的，沒有解析過")
(print "      要解析旗標請用 spork/argparse（docs/04）")
(秀 "(dyn *executable*)" (dyn *executable*))
(秀 "(dyn *current-file*)" (dyn *current-file*))
(秀 "(dyn *syspath*)" (dyn *syspath*))

(節 "import 找不到檔時看這兩個")
(printf "  %-32s => %j 筆" "module/paths" (length module/paths))
(print "    每筆是 [路徑樣板 種類 檢查函式]；挑幾筆真的是路徑樣板的來看：")
(def 樣板 (filter |(and (string? (get $ 0)) (string/find "/" (get $ 0))) module/paths))
(each e (slice 樣板 0 4)
  (printf "      %-34s 種類 %j" (get e 0) (get e 1)))
(print "    「could not find module」列出的候選路徑就是這張表算出來的")
(printf "  %-32s => %j" "module/cache 的型別" (type module/cache))
(print "    同一支檔只會被載一次，重複 import 拿的是快取")

(節 "自己定義：defdyn")
(defdyn *我的設定* "示範用：自訂的動態變數")
(秀 "*我的設定* 求值" *我的設定*)
(秀 "沒設過 (dyn *我的設定*)" (dyn *我的設定*))
(秀 "沒設過但給預設值" (dyn *我的設定* :預設))
(with-dyns [*我的設定* :開]
  (秀 "with-dyns 區塊裡" (dyn *我的設定*)))
(秀 "離開區塊之後" (dyn *我的設定*))
(print "  一行就換到「打錯會被編譯器擋、doc 查得到」的待遇")

(節 "⚠ dyn 是 per-fiber 的")
(def f (fiber/new (fn [] (yield (dyn *我的設定*)))))
(with-dyns [*我的設定* :外面設的]
  (秀 "在 with-dyns 裡 resume 一個 fiber" (resume f)))
(print "  細節見 docs/12c 與 docs/15")

(print "\n✓ dyn-vars 跑完")
