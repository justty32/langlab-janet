# 配合 course/7-2-資源收尾-defer-with.md 與 7-2b-defer-與-with-的坑.md
#   janet examples/course/7-2.janet

(print "== defer：離開這個區塊時一定跑 ==")
(printf "回傳 %j"
        (defer (print "收尾")
          (print "做事")
          (+ 1 2)))

(print "== body 炸了照樣收尾 ==")
(printf "%j" (protect (defer (print "cleanup ran") (error "body boom"))))

(print "== 迴圈 break 也算離開 ==")
(defn 找到就停 []
  (defer (print "收尾")
    (each i [1 2 3]
      (when (= i 2) (break))
      (print "i=" i))))
(找到就停)

(print "== 巢狀 defer：後開的先收 ==")
(defer (print "外層收尾")
  (defer (print "內層收尾")
    (print "body")))

(print "== with：開了就一定關 ==")
(printf "%j" (with [f (file/temp)]
               (file/write f "hello")
               (file/seek f :set 0)
               (file/read f :all)))
(def f (file/temp))
(with [g f] (file/write g "x"))
(printf "離開 with 之後再寫：%j" (protect (file/write f "y")))

(print "== body 炸了，with 照樣關 ==")
(def 資源 @{:close (fn [self] (print "closed"))})
(printf "%j" (protect (with [r 資源] (error "boom"))))

(print "== 沒有 :close 的東西：第三個位置放收尾函式 ==")
(defn 關 [r] (print "custom close " (r :name)))
(printf "回傳 %j" (with [r @{:name "db"} 關] (r :name)))

(print "== 坑：參數順序跟 Go 相反 ==")
(def log @[])
(defer (array/push log :cleanup) (array/push log :body))
(printf "%j" log)

(print "== 坑：沒有 :close 就炸 ==")
(printf "%j" (protect (with [r @{}] :ok)))

(print "== 坑：收尾自己炸會蓋掉 body 的錯誤 ==")
(printf "%j" (protect (defer (error "cleanup boom") (error "body boom"))))

# ---- 練習解答 ----
(print "== 練習 1：忙一下 ==")
(var 狀態 :idle)
(defn 忙一下 [f]
  (set 狀態 :busy)
  (defer (set 狀態 :idle)
    (f)))
(printf "%j" (protect (忙一下 (fn [] (error "job crashed")))))
(printf "炸完之後狀態：%j" 狀態)

(print "== 練習 2：假資源計數 ==")
(var 關閉次數 0)
(defn 開 [] @{:close (fn [self] (++ 關閉次數))})
(with [r (開)] :ok)
(protect (with [r (開)] (error "第二次炸")))
(with [r (開)] :ok)
(printf "關閉次數：%j" 關閉次數)

(print "== 練習 3：巢狀 with 的關閉順序 ==")
(defn 具名資源 [name]
  @{:name name :close (fn [self] (print "關 " (self :name)))})
(with [a (具名資源 "A")]
  (with [b (具名資源 "B")]
    (print "用 " (a :name) " 和 " (b :name))))
