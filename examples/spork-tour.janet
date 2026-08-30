# spork 導覽 —— 配合 docs/27-spork-全覽.md
#
# 跑法：janet examples/spork-tour.janet
#
# 十四個模組各跑一段，讓你一次看完 spork 大概能幹嘛。
# 各模組的實測筆記在 reference/spork/，完整 API 查官方 github.com/janet-lang/spork。

(import spork/misc)
(import spork/path)
(import spork/base64)
(import spork/utf8)
(import spork/regex)
(import spork/schema)
(import spork/data)
(import spork/date)
(import spork/htmlgen)
(import spork/fmt)
(import spork/zip)
(import spork/randgen)
(import spork/generators :as gen)
(import spork/ev-utils)

(defn 標題 [s] (print "\n─── " s " ───"))
(defn 秀 [expr v] (printf "  %-40s => %q" expr v))

# ── misc：早該內建但沒有的小工具 ─────────────────────────────────────────
(標題 "spork/misc —— 雜貨店")

(秀 "(map inc {:a 1 :b 2})  內建，key 沒了" (map inc {:a 1 :b 2}))
(秀 "(misc/map-vals inc {:a 1 :b 2})  key 留著" (misc/map-vals inc {:a 1 :b 2}))
(秀 "(misc/select-keys {:a 1 :b 2} [:a])" (misc/select-keys {:a 1 :b 2} [:a]))
(秀 "(misc/randomize-array @[1 2 3 4 5])" (misc/randomize-array @[1 2 3 4 5]))
(秀 "(misc/trim-suffix \".txt\" \"a.txt\")" (misc/trim-suffix ".txt" "a.txt"))

# ── path：組路徑不要自己接字串 ───────────────────────────────────────────
(標題 "spork/path —— 路徑")

(秀 "(path/join \"a\" \"b\" \"c.txt\")" (path/join "a" "b" "c.txt"))
(秀 "(path/ext \"a/b/c.txt\")" (path/ext "a/b/c.txt"))
(秀 "(path/basename \"a/b/c.txt\")" (path/basename "a/b/c.txt"))
(秀 "(path/posix/join \"a\" \"b\")" (path/posix/join "a" "b"))
(秀 "(path/win32/join \"a\" \"b\")  另一套也叫得到" (path/win32/join "a" "b"))

# ── base64 / utf8：編碼 ───────────────────────────────────────────────────
(標題 "spork/base64 與 spork/utf8 —— 編碼（原生模組）")

(秀 "(base64/encode \"hello\")" (base64/encode "hello"))
(秀 "(base64/decode \"aGVsbG8=\")" (base64/decode "aGVsbG8="))
(秀 "(utf8/decode-rune \"中\")  碼點 + 佔幾 byte" (utf8/decode-rune "中"))
(printf "  ↑ 內建的 (length \"中\") 是 %q，因為那是 byte 數不是字元數" (length "中"))

# ── regex：其實是翻譯成 PEG ───────────────────────────────────────────────
(標題 "spork/regex —— regex 語法，PEG 引擎")

(秀 "(regex/find \"[0-9]+\" \"abc123def\")  回索引" (regex/find "[0-9]+" "abc123def"))
(秀 "(regex/replace-all \"[0-9]\" \"#\" \"a1b2c3\")" (regex/replace-all "[0-9]" "#" "a1b2c3"))
(秀 "(regex/source \"[0-9]+\")  ← 它編成了 PEG！" (regex/source "[0-9]+"))
(print "  ↑ spork/regex 不是另一套引擎，是把 regex 翻成內建 PEG（見 docs/14-peg.md）。")

# ── schema：驗證資料形狀 ──────────────────────────────────────────────────
(標題 "spork/schema —— 宣告式驗證")

(def 使用者? (schema/predicate (props :name :string :age :number)))
(秀 "{:name \"Alice\" :age 30}" (使用者? {:name "Alice" :age 30}))
(秀 "{:name \"Alice\" :age \"30\"}  age 型別錯" (使用者? {:name "Alice" :age "30"}))
(def 驗 (schema/validator :number))
(秀 "validator 版失敗會拋錯，訊息是" (last (protect (驗 "abc"))))

# ── data：兩份資料差在哪 ──────────────────────────────────────────────────
(標題 "spork/data —— diff")

(秀 "(data/diff {:a 1 :b 2} {:a 1 :b 3})" (data/diff {:a 1 :b 2} {:a 1 :b 3}))
(print "  ↑ 回 [只在左邊 只在右邊 兩邊相同]")

# ── date：日期運算 ────────────────────────────────────────────────────────
(標題 "spork/date —— 日期物件")

(def 今天 (date/utc-now))
(秀 "(date/to-string 今天 \"yyyy-MM-dd\")" (date/to-string 今天 "yyyy-MM-dd"))
(秀 "(date/to-string 今天 \"YYYY-MM-DD\")  ⚠ 大寫" (date/to-string 今天 "YYYY-MM-DD"))
(print "  ⚠ token 大小寫敏感：MM=月 mm=分；YYYY 與 DD 不是 token，會原樣留著且不報錯。")
(秀 "(date/to-string (date/add 今天 :days 3) \"yyyy-MM-dd\")"
    (date/to-string (date/add 今天 :days 3) "yyyy-MM-dd"))
(秀 "(date/leap-year? 2024)" (date/leap-year? 2024))

# ── htmlgen / fmt：產生輸出 ───────────────────────────────────────────────
(標題 "spork/htmlgen 與 spork/fmt —— 產生輸出")

(秀 "(htmlgen/html [:p {:class \"x\"} \"hi\"])" (htmlgen/html [:p {:class "x"} "hi"]))
(printf "  fmt/format 把亂寫的程式碼排好：%q" (fmt/format "(defn f[x](+ x 1))"))

# ── zip：壓縮 ─────────────────────────────────────────────────────────────
(標題 "spork/zip —— 壓縮（原生模組）")

(def 原文 (string/repeat "hello " 20))
(def 壓過 (zip/compress 原文))
(printf "  %d bytes 壓成 %d bytes，解回來一樣嗎？ %q"
        (length 原文) (length 壓過) (= 原文 (string (zip/decompress 壓過))))

# ── randgen：進階抽樣 ─────────────────────────────────────────────────────
(標題 "spork/randgen —— 加權與常態分布")

(秀 "(randgen/rand-gaussian)  常態分布" (randgen/rand-gaussian))
(def 抽 (seq [_ :range [0 3000]] (randgen/rand-weights [1 10 1])))
(秀 "rand-weights [1 10 1] 抽 3000 次的分布" (frequencies 抽))
(print "  ↑ 權重 10 的那個（索引 1）出現次數應該約是另外兩個的十倍。")

# ── generators：真正的惰性序列 ────────────────────────────────────────────
(標題 "spork/generators —— 惰性")

(秀 "(gen/to-array (gen/take 3 (gen/range 0 1000000)))"
    (gen/to-array (gen/take 3 (gen/range 0 1000000))))
(print "  ↑ 一百萬的 range 只真的算了三個——內建的 map/filter 是 eager，這套不是。")

# ── ev-utils：平行處理 ────────────────────────────────────────────────────
(標題 "spork/ev-utils —— pmap 是真的並行")

(秀 "(ev-utils/pmap (fn [x] (* x x)) [1 2 3 4 5])"
    (ev-utils/pmap (fn [x] (* x x)) [1 2 3 4 5]))

(def t0 (os/clock :monotonic))
(ev-utils/pmap (fn [_] (ev/sleep 0.1)) (range 5))
(printf "  五個各睡 0.1 秒的工作，牆上時間 %.3f 秒（循序做要 0.5 秒）"
        (- (os/clock :monotonic) t0))

(print "\n完。實測筆記在 reference/spork/，完整 API 查 github.com/janet-lang/spork。")
