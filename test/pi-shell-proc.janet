# pi-shell：**子行程管線本身** —— stdin 餵得進去、stdout 讀得回來、退出碼正確。
#
# 不真的請 pi／claude 做事（要花錢、而且它們預設帶 bash/edit/write 會動檔案）。
# 拿 cat／sh 當替身驗這一層就夠了——proc.janet 本來就不認識任何 agent。

(import ../modules/pi-shell/init :as agent)

# ── stdin：走「內容已就緒的暫存檔句柄」，不是 spawn 後才寫的管線 ────
# ★ feed-file 一定要倒帶到 0，否則子行程從檔尾讀 = 靜默讀到空
(def f (agent/feed-file "abc"))
(assert (= 0 (file/tell f)) "feed-file 交出來的句柄要停在檔頭")
(assert (= "abc" (string (file/read f :all))) "內容真的在裡面")
(file/close f)

(def r1 (agent/run ["cat"] "餵進去的內容\n"))
(assert (= 0 (r1 :code)) "cat 正常結束")
(assert (= "餵進去的內容\n" (r1 :out)) "寫進去的東西原樣讀得回來")

# 不給 stdin 也要立刻收到 EOF、不會空等
(def r2 (agent/run ["cat"]))
(assert (= 0 (r2 :code)))
(assert (= "" (r2 :out)))

# 非 0 退出碼是**資料**不是例外
(def r3 (agent/run ["sh" "-c" "exit 3"]))
(assert (= 3 (r3 :code)) "退出碼原樣回傳")

# 輸出量大於單次 read 也要收得完整（驗「讀寫分 fiber」沒有互卡）
(def big (string/repeat "x" 200000))
(def r4 (agent/run ["cat"] big))
(assert (= (length big) (length (r4 :out))) "大量資料不會卡死或截斷")

(print "pi-shell 子行程管線測試通過 ✓")
