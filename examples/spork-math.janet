# 配合 docs/42-spork-math.md
#
#   janet examples/spork-math.janet
#
# spork/math 的三大塊（統計／數論／線性代數），以及四個猜不到的地方。

(import spork/math :as m)

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-30s => %j" 說明 結果))

(節 "⚠ 猜不到①：沒有 mean")
(printf "  %-30s => %s" "m/mean 存在嗎"
        (let [r (compile '(do m/mean) (curenv))]
          (if (table? r) (string "compile error: " (r :error)) "存在")))
(print "  有 geometric-mean / harmonic-mean / add-to-mean，就是沒有算術平均")
(def xs [2 4 4 4 5 5 7 9])
(def 平均 (/ (sum xs) (length xs)))
(秀 "自己算 (/ (sum xs) (length xs))" 平均)
(printf "  %-30s => %s" "z-score 的簽名"
        (first (string/split "\n" (get (dyn 'm/z-score) :doc))))
(秀 "(m/z-score 5 平均 標準差)" (m/z-score 5 平均 (m/standard-deviation xs)))
(print "  ↑ 平均要你自己餵進去——這是「沒有 mean」的連帶後果")
(print "  ⚠ 而且那是 compile error 不是執行期錯，try 攔不到（見 docs/33）")

(節 "⚠ 猜不到②：函式名有拼字錯誤")
(秀 "(m/binominal-coeficient 5 2)" (m/binominal-coeficient 5 2))
(print "  正確拼法是 binomial coefficient，但函式叫 binominal-coeficient")
(print "  多一個 n、少一個 f——照正確拼法你永遠找不到它")
(print "\n  拿正確拼法去搜，會一個都找不到：")
(defn 搜 [片段]
  (sort (filter |(and (symbol? $)
                      (string/has-prefix? "m/" (string $))
                      (string/find 片段 (string $)))
                (keys (curenv)))))
(秀 "  搜 \"nomial\"（正確拼法的字尾）" (搜 "nomial"))
(秀 "  搜 \"nominal\"（實際的拼法）" (搜 "nominal"))
(print "  ↑ 「binomial」含 nomial，「binominal」含的是 nominal——差一個字母就搜不到")
(print "  所以：先把模組列一次再用，不要憑英文直覺猜名字")

(節 "⚠ 猜不到③：有些函式只吃可變 array")
(printf "  %-30s => %s" "(m/permutations [1 2 3])"
        (try (do (m/permutations [1 2 3]) "成功") ([e] (string "報錯：" e))))
(秀 "(m/permutations @[1 2 3])" (m/permutations @[1 2 3]))
(print "  因為內部用 swap 原地交換。錯誤訊息只講型別，不會提示你「加個 @」")

(節 "⚠ 猜不到④：primes 是無界生成器")
(秀 "(m/primes) 的型別" (type (m/primes)))
(秀 "(take 10 (m/primes))" (take 10 (m/primes)))
(print "  它是 fiber，要多少取多少——直接丟給 length 或 pp 會跑不完")
(print "  docs/25 說「Janet 沒有惰性序列」，這就是那條規則的例外（用 fiber 做的）")

(節 "敘述統計")
(秀 "資料" xs)
(each [n f] [["median" m/median] ["mode" m/mode]
             ["variance（母體，除以 n）" m/variance]
             ["sample-variance（樣本，n−1）" m/sample-variance]
             ["standard-deviation" m/standard-deviation]
             ["sample-standard-deviation" m/sample-standard-deviation]
             ["geometric-mean" m/geometric-mean]
             ["harmonic-mean" m/harmonic-mean]
             ["root-mean-square" m/root-mean-square]
             ["interquartile-range" m/interquartile-range]
             ["extent（最小與最大）" m/extent]]
  (printf "  %-30s => %j" n (f xs)))
(秀 "(m/quantile xs 0.5)" (m/quantile xs 0.5))
(print "  ⚠ 沒有前綴的是**母體**版，sample- 那組才是樣本版（分母 n−1）")
(print "     這跟多數統計軟體的預設相反（R 的 var 是樣本版）")
(print "     拿實驗資料算統計量時幾乎都該用 sample- 那組")
(秀 "sum-compensated（Kahan 補償求和）" (m/sum-compensated [0.1 0.2 0.3]))
(秀 "  對照普通的 sum" (sum [0.1 0.2 0.3]))

(節 "檢定與迴歸")
(秀 "sample-correlation" (m/sample-correlation [1 2 3 4 5] [2 4 5 4 5]))
(def 迴歸 (m/linear-regression [[1 2] [2 4] [3 5]]))
(秀 "linear-regression → {:m 斜率 :b 截距}" 迴歸)
(秀 "  代 x=4 進迴歸線" ((m/linear-regression-line 迴歸) 4))
(秀 "t-test（單樣本，對 3）" (m/t-test [1 2 3 4 5] 3))
(秀 "approx-eq 0.1 0.1000000001" (m/approx-eq 0.1 0.1000000001))
(秀 "approx-eq 0.1 0.2" (m/approx-eq 0.1 0.2))
(print "  approx-eq 就是 docs/21 說的「浮點數比差值」，不用自己寫")

(節 "線性代數：矩陣就是陣列的陣列，沒有專門型別")
(def A [[1 2] [3 4]])
(秀 "A" A)
(秀 "(m/det A)" (m/det A))
(秀 "(m/trans A)" (m/trans A))
(秀 "(m/ident 2)" (m/ident 2))
(秀 "(m/matmul A (m/ident 2))" (m/matmul A (m/ident 2)))
(秀 "(m/dot [1 2] [3 4])" (m/dot [1 2] [3 4]))
(秀 "(m/size A)  [列 行]" (m/size A))
(print "  ⚠ 輸入吃 tuple，輸出一律是 @[@[…]]（可變）——要不可變自己 freeze")

(節 "數論")
(each [n v] [["(m/prime? 97)" (m/prime? 97)]
             ["(m/next-prime 100)" (m/next-prime 100)]
             ["(m/factorial 10)" (m/factorial 10)]
             ["(m/factor 84)  質因數分解" (m/factor 84)]
             ["(m/powmod 2 10 1000)" (m/powmod 2 10 1000)]
             ["(m/invmod 3 11)  模反元素" (m/invmod 3 11)]]
  (printf "  %-30s => %j" n v))
(print "  ⚠ 吃的是一般 Janet 數字，所以受 2^53 精度限制（見 docs/21）")
(秀 "  (m/factorial 25) 已經不精確" (m/factorial 25))

(print "\n✓ spork-math 跑完")
