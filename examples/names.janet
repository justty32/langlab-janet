# 配合 docs/13-symbol-keyword-字串.md
#
#   janet examples/names.janet
#
# 四種「名字」型別：string / buffer / symbol / keyword。
# 它們印出來很像，但彼此不相等——這是最常咬人的地方。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-34s => %j" 說明 結果))
(defn 秀s [說明 結果] (printf "  %-34s => %s" 說明 結果))

(節 "四種名字型別")
(each [寫法 v] [["\"abc\"  字串" "abc"]
                ["@\"abc\" buffer" @"abc"]
                ["'abc   symbol" 'abc]
                [":abc   keyword" :abc]]
  (printf "  %-18s type=%-10j 印出來 %s" 寫法 (type v) (string v)))
(print "  ⚠ 四個「印出來」長得一模一樣——這就是麻煩的來源")

(節 "★ 最容易踩的坑：跨型別 = 一律 false")
(秀 "(= \"abc\" :abc)" (= "abc" :abc))
(秀 "(= \"abc\" 'abc)" (= "abc" 'abc))
(秀 "(= 'abc :abc)" (= 'abc :abc))
(秀 "(= \"abc\" @\"abc\")  連 buffer 也是" (= "abc" @"abc"))
(print "  ⚠ 最後一個特別陰——buffer 跟 string 內容一樣卻不相等")
(秀 "轉成 string 才等" (= "abc" (string @"abc")))
(print "  所以從外部（檔案、網路、CLI）拿到的東西，比較之前先想清楚它是哪一種")

(節 "互轉")
(秀s "(symbol \"abc\")" (symbol "abc"))
(秀s "(keyword \"abc\")" (keyword "abc"))
(秀 "(string :abc)" (string :abc))
(秀 "(string 'abc)" (string 'abc))
(秀s "keyword → symbol 要繞一圈" (symbol (string :abc)))
(print "  沒有 keyword→symbol 的直接函式，一律經過 string")

(節 "⚠ %j 與 %s 對 keyword 印出來不一樣")
(printf "  %-34s => %j" "%j 印 :abc（帶冒號，可讀回去）" :abc)
(printf "  %-34s => %s" "%s 印 :abc（不帶冒號）" :abc)
(print "  寫給機器讀（要能 parse 回來）用 %j；給人看用 %s")

(節 "⚠ 造得出來、但原始碼裡打不出來的 keyword")
(def 怪 (keyword "有 空格"))
(秀 "型別還是 keyword" (type 怪))
(秀s "用 %s 印得出來" 怪)
(printf "  %-34s => %s" "用 %j 印"
        (try (string/format "%j" 怪) ([e] (string "報錯：" e))))
(print "    ↑ 因為它沒有合法的字面寫法，jdn 印不出來")
(秀 "但它照樣能當字典的鍵" (get {怪 :可以} 怪))
(print "  ⚠ 用 (keyword 使用者輸入) 造 key 時要有心理準備：存得進去、印不出來")

(節 "實用①：字串 key 的 table 轉成 keyword key")
(def 從json {"name" "Alice" "age" 30})
(秀 "原本（JSON 解出來常是這樣）" 從json)
(秀 "轉完" (tabseq [[k v] :pairs 從json] (keyword k) v))
(print "  spork/json 的 :keywords 參數可以直接要它這樣解（見 docs/03）")

(節 "實用②：用執行期算出來的名字取值")
(def cfg {:port 4000 :host "127.0.0.1"})
(def 欄位 "port")
(秀 "(get cfg (keyword 欄位))" (get cfg (keyword 欄位)))
(print "  ⚠ 不能寫 (get cfg 欄位)——字串 key 跟 keyword key 是兩回事：")
(秀 "(get cfg \"port\")" (get cfg "port"))

(節 "實用③：用執行期算出來的名字取「綁定」")
(秀 "(type (dyn (symbol \"print\")))" (type (dyn (symbol "print"))))
(秀 "拿到的是綁定表，:value 才是東西" (type (get (dyn (symbol "print")) :value)))
(print "  ⚠ 名字不存在時 dyn 回 nil，不報錯——自己檢查")
(秀 "(dyn (symbol \"絕對沒這個\"))" (dyn (symbol "絕對沒這個")))

(節 "為什麼有 symbol 又有 keyword")
(print "  symbol  會被求值——寫 abc 就是「去查 abc 這個綁定」")
(printf "    %-30s => %j" "(eval 'print) 查得到綁定" (type (eval 'print)))
(print "      （:cfunction＝C 寫的內建，不是 :function——區分見 docs/38）")
(printf "    %-30s => %s" "(eval '沒定義過的名字)"
        (try (do (eval '沒定義過的名字) "有值") ([e] (string "報錯：" e))))
(print "  keyword 求值就是自己——所以拿來當 key、當標籤最安全")
(秀 "(eval :abc)" (eval :abc))

(print "\n✓ names 跑完")
