# 練習題的參考解答必須真的會過。
#
# 為什麼要這支：解答會腐化（Janet 升版、我改了題目卻忘了改解答），
# 而「解答錯的練習題」比沒有練習題還糟——學的人會以為是自己寫錯。
#
# 做法：每份解答各用一個獨立行程跑（它們自己結尾就有 assert），檢查 exit code。
# ⚠ 不能在同一個行程裡 dofile 它們——它們定義同名的 檢查／過／錯，會互相蓋掉。

(def 目錄 "exercises/solutions")

(def 解答們
  (sort (filter |(string/has-suffix? ".janet" $) (os/dir 目錄))))

(assert (>= (length 解答們) 3)
        (string/format "只找到 %d 份解答，路徑是不是變了？" (length 解答們)))

(var 壞 0)
(each 檔 解答們
  (def 路徑 (string 目錄 "/" 檔))
  # :p = 用 PATH 找 janet；回傳乾淨的 exit code（見 docs/39 為什麼不用 os/shell）
  # ⚠ 子行程寫的是**真的 fd**，(with-dyns [*out* …]) 攔不到——要把它的輸出導掉
  #   得用 :x 給它自己的 stdout/stderr。這裡導到 /dev/null，只留 exit code。
  (def 黑洞 (os/open "/dev/null" :w))
  (def code (os/execute ["janet" 路徑] :px {:out 黑洞 :err 黑洞}))
  (:close 黑洞)
  (if (zero? code)
    (printf "  ✓ %s" 檔)
    (do (++ 壞) (eprintf "  ✘ %s（exit %d）" 檔 code))))

(assert (zero? 壞)
        (string/format "有 %d 份參考解答沒過——解答本身壞了，或題目改了忘了同步。" 壞))

(printf "練習題解答：%d 份全過 ✓" (length 解答們))
