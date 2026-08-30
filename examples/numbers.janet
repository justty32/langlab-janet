# 配合 docs/21-數字與位元.md
#
#   janet examples/numbers.janet
#
# 「全部都是 double」這件事的每一個後果，都在這裡跑出來看。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-34s => %j" 說明 結果))
(defn 秀s [說明 結果] (printf "  %-34s => %s" 說明 結果))

(節 "只有一種數字型別：double")
(秀 "(type 1)" (type 1))
(秀 "(type 1.5)" (type 1.5))
(秀 "(= 1 1.0)  整數與浮點沒有分別" (= 1 1.0))

(節 "後果①：整數精度只到 2^53")
(秀 "2^53" (math/pow 2 53))
(秀 "(+ 9007199254740992 1) 有變嗎" (= (+ 9007199254740992 1) 9007199254740992))
(print "  ⚠ 連字面值都存不住——你打進去的數字會被改掉：")
(秀 "打 9007199254740993 進去，存到的是" 9007199254740993)

(節 "後果②：浮點數不要用 = 比")
(秀 "(+ 0.1 0.2)" (+ 0.1 0.2))
(秀 "(= 0.3 (+ 0.1 0.2))" (= 0.3 (+ 0.1 0.2)))
(秀 "比差值才對" (< (math/abs (- 0.3 (+ 0.1 0.2))) 1e-9))

(節 "四種除法各不相同")
# ⚠ printf 的寬度旗標對 %j 無效（本 repo 記過的坑），所以先轉成字串再排版
(defn 欄 [v] (string/format "%-8s" (string/format "%j" v)))
(printf "  %-10s %-8s %-8s %-8s %s" "" "/" "div" "mod" "%")
(each [a b] [[7 2] [-7 2] [7 -2]]
  (printf "  %-10s %s%s%s%s"
          (string/format "%d, %d" a b)
          (欄 (/ a b)) (欄 (div a b)) (欄 (mod a b)) (欄 (% a b))))
(print "  / 給浮點結果；div 是整數除法")
(print "  ⚠ mod 與 % 對負數不一樣：mod 跟除數同號（數學上的模），% 跟被除數同號（C 的 %）")

(節 "⚠ 除以零不會報錯")
(秀s "(/ 1 0)" (string (/ 1 0)))
(秀s "(/ -1 0)" (string (/ -1 0)))
(秀s "(/ 0 0)" (string (/ 0 0)))
(秀s "(div 1 0)  連整數除法也是" (string (div 1 0)))
(print "  ⚠ 這代表「除以零」不能當成錯誤路徑來測（見 docs/23）")
(秀 "nan 連自己都不等於自己" (= (/ 0 0) (/ 0 0)))
(秀 "所以要用 (nan? x) 判斷" (nan? (/ 0 0)))

(節 "⚠ 位元運算是 32 位元有號的，不是 64")
(秀 "(blshift 1 30)" (blshift 1 30))
(秀 "(blshift 1 31)  ← 翻成負數了" (blshift 1 31))
(秀 "(blshift 1 32)  ← 繞回來變 1" (blshift 1 32))
(秀 "(blshift 1 33)" (blshift 1 33))
(print "  ↑ 位移量被 mod 32，而且第 31 位是符號位——兩個都不會報錯")
(秀 "(bnot 0)" (bnot 0))
(print "  要真的做 64 位元位元運算，用下面的 int/u64")

(節 "真的需要 64 位元整數：int/s64 與 int/u64")
(秀s "(int/s64 \"9007199254740993\")  精確" (string (int/s64 "9007199254740993")))
(秀s "跟一般數字混算也可以" (string (+ (int/s64 1) 1)))
(秀s "(int/u64 1) + (int/u64 2)" (string (+ (int/u64 1) (int/u64 2))))
(秀 "它們是 abstract type（見 docs/38）" [(type (int/s64 1)) (type (int/u64 1))])
(print "  ⚠ 印出來要用 (string x)——%j 對 abstract type 印不出來")

(節 "取整的四個函式，對負數各走各的")
(printf "  %-12s %-8s %-8s %-8s %s" "" "floor" "ceil" "round" "trunc")
(each v [1.5 -1.5 2.5 -0.5]
  (printf "  %-12s %s%s%s%s"
          (string/format "%j" v)
          (欄 (math/floor v)) (欄 (math/ceil v)) (欄 (math/round v)) (欄 (math/trunc v))))
(print "  ⚠ floor 往負無窮走、trunc 往零走——負數時兩者不同")
(print "  ⚠ 上面那個 -0 不是印錯：IEEE 754 真的有負零")
(秀 "(= 0 -0.0)  但它等於 0" (= 0 (math/ceil -0.5)))
(print "  ⚠ round 是「一半往離零的方向」，不是銀行家捨入：")
(秀 "(math/round 2.5) 與 (math/round 3.5)" [(math/round 2.5) (math/round 3.5)])

(節 "字面值的其他寫法")
(秀 "8r644   八進位" 8r644)
(秀 "16rFF   十六進位" 16rFF)
(秀 "2r1010  二進位" 2r1010)
(秀 "1_000_000  底線分隔" 1_000_000)
(秀 "1e3" 1e3)
(print "  ⚠ 沒有 0o644 / 0644 這種寫法，會被當成十進位（見 docs/39）")

(節 "字串轉數字")
(秀 "(scan-number \"42\")" (scan-number "42"))
(秀 "(scan-number \"0x1F\")  吃十六進位" (scan-number "0x1F"))
(秀 "(scan-number \"abc\")   失敗回 nil" (scan-number "abc"))
(print "  ⚠ 回 nil 不是拋錯——記得檢查")

(print "\n✓ numbers 跑完")
