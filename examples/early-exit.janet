# 配合 docs/01d-提早離開-return-break-continue.md
#
#   janet examples/early-exit.janet
#
# 每個情境印「C 的寫法 → Janet 的寫法 → 實際結果」。結果全是當場跑出來的。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 對照 [c j r]
  (printf "  C     : %s" c)
  (printf "  Janet : %s" j)
  (printf "  結果  : %s" (string/format "%j" r)))

(節 "① 尾端 return：最後一個運算式就是回傳值")
(defn sign [n] (cond (< n 0) :負 (zero? n) :零 :正))
(對照 "if (n<0) return NEG; if (n==0) return ZERO; return POS;"
      "(cond (< n 0) :負 (zero? n) :零 :正)"
      (map sign [-5 0 3]))

(節 "② 提早 return：函式 body 裡的 break 就是 return")
(defn safe-div [a b]
  (when (zero? b) (break :除以零))
  (/ a b))
(對照 "if (b == 0) return ERR;  return a / b;"
      "(when (zero? b) (break :除以零)) (/ a b)"
      [(safe-div 1 0) (safe-div 6 3)])

(節 "③ 迴圈裡的 break：只出迴圈，不出函式；(break 值) 的值被丟掉")
(defn f [] (each x [1 2 3] (when (= x 2) (break))) :跑完)
(對照 "for (...) { if (x==2) break; }  return DONE;"
      "(each x xs (when (= x 2) (break))) :跑完"
      (f))
(對照 "v = -1; for (...) { if (x==2) { v = x; break; } }"
      "(each x [1 2 3] (when (= x 2) (break x)))   ⚠ 值丟掉"
      (each x [1 2 3] (when (= x 2) (break x))))
(defn 找 [xs 目標]
  (var 答 nil)
  (each x xs (when (= x 目標) (set 答 x) (break)))
  答)
(對照 "同上，要把 x 帶出來"
      "(var 答 nil) (each … (set 答 x) (break)) 答"
      (找 [1 2 3] 2))

(節 "④ ⚠ defer 包在迴圈裡：break 只離開 defer 那層")
(def log @[])
(each x [1 2 3]
  (defer (array/push log [:收尾 x])
    (when (= x 2) (break))
    (array/push log [:body x])))
(對照 "（C 沒有 defer；Go 的 defer 只在函式結束時跑）"
      "(each x xs (defer 收尾 (when (= x 2) (break)) body))"
      log)
(print "  x=2 跳過 body、收尾照跑，但 x=3 還是進來了——break 沒有跳出 each")

(節 "⑤ continue：用過濾，不用跳")
(對照 "for (i=0;i<6;i++) { if (i==2) continue; push(i); }"
      "(seq [i :range [0 6] :unless (= i 2)] i)"
      (seq [i :range [0 6] :unless (= i 2)] i))
(def r @[])
(each x [1 2 3 4] (unless (even? x) (array/push r x)))
(對照 "for (...) { if (x%2==0) continue; push(x); }"
      "(each x xs (unless (even? x) (array/push r x)))"
      r)

(節 "⑥ 跳出巢狀迴圈：label + return（C 的 goto、Go 的 break outer）")
(對照 "for(i) for(j) if (i==1&&j==2) goto out; ... out:"
      "(label outer (for i 0 3 (for j 0 3 (when … (return outer [i j])))))"
      (label outer
        (for i 0 3
          (for j 0 3
            (when (= [i j] [1 2]) (return outer [i j]))))))
(對照 "for(i) { for(j) if (j==1) goto next_i; ... next_i: }"
      "(seq [i …] (label next (for j … (return next [i :跳])) [i :跑完]))"
      (seq [i :range [0 3]]
        (label next
          (for j 0 3 (when (= j 1) (return next [i :跳])))
          [i :跑完])))
(對照 "（沒人跳）"
      "(label out 1 2 3) 回最後一個；(return out) 不給值是 nil"
      [(label out 1 2 3) (label out (return out))])

(節 "⑦ label 能跨函式（閉包在 label 裡定義），但名字是詞法的")
(對照 "（C 的 goto 不能跨函式）"
      "(label out (defn g [] (return out :跳)) (g) :沒跳)"
      (label out (defn g [] (return out :跳)) (g) :沒跳))
(對照 "（拼錯 label：C 是連結錯誤）"
      "(compile '(return nowhere 1))"
      ((compile '(return nowhere 1)) :error))

(節 "⑧ prompt：tag 是任意值，像 longjmp")
(defn 找到就回 [] (return :out :跳))
(對照 "setjmp(env); … 深處 longjmp(env, 1);"
      "(prompt :out (找到就回) :沒跳)"
      (prompt :out (找到就回) :沒跳))
(def k (fiber/new (fn [] (try (return :q :跳) ([e] :try攔到))) :u))
(對照 "（longjmp 到沒 setjmp 的 env：UB）"
      "找不到 prompt：try 攔不到，只有 (fiber/new f :u) 接得住"
      [(resume k) (fiber/status k)])
(print "  ⚠ 沒人接的話程式直接死，印 user0: <tuple 0x…>")

(節 "⑨ 自己玩 signal：想區分多種跳出時才需要")
(def s (fiber/new (fn [] (for i 0 10 (when (= i 3) (signal 1 [:找到 i]))) :跑完) :u))
(對照 "（C 沒有）"
      "(signal 1 [:找到 i]) 配 (fiber/new f :u)"
      [(resume s) (fiber/status s)])

(print "\n✓ early-exit 跑完——接著看 docs/43／44／45 的逐條語法對照")
