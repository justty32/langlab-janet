# 配合 course/3-2-拿放改.md
# 跑法：janet examples/course/3-2.janet

(print "== 拿：get 和「把容器當函式叫」 ==")
(def 分數 @[90 85 77])
(print (get 分數 0))   # 90   位置從 0 數起
(print (分數 1))       # 85   跟 get 一樣，比較短
(def 人 @{:name "Ann" :age 30})
(print (get 人 :name))   # Ann
(print (人 :age))        # 30

(print "== 拿不到會怎樣 ==")
(pp (get 分數 10))   # nil   超出範圍
(pp (get 分數 -1))   # nil   沒有負索引
(pp (get 人 :email))          # nil   鍵不存在
(pp (get 人 :email "none"))   # "none"   第三個參數是預設值
(pp (last 分數))     # 77   要最後一個用 last

(print "== 一定要拿到：in ==")
(print (in 分數 1))   # 85
(def [成功? 錯誤] (protect (in 分數 10)))
(print "in 拿不到：" 成功? " / " 錯誤)
# in 拿不到：false / expected integer key for array in range [0, 3), got 10

(print "== 放：put ==")
(def 人2 @{:name "Ann"})
(pp (put 人2 :age 30))   # @{:age 30 :name "Ann"}   新增
(pp (put 人2 :age 31))   # @{:age 31 :name "Ann"}   覆寫
(pp (put 分數 0 100))    # @[100 85 77]
(pp (put 人2 :age nil))  # @{:name "Ann"}   值放 nil 等於刪鍵

(print "== 改：update ==")
(def 人3 @{:name "Ann" :age 30})
(pp (update 人3 :age inc))        # @{:age 31 :name "Ann"}
(pp (update 人3 :age |(* $ 2)))   # @{:age 62 :name "Ann"}

(print "== 尾巴加、尾巴拿：array/push、array/pop ==")
(def 待辦 @[])
(array/push 待辦 "buy milk")
(array/push 待辦 "laundry")
(print (length 待辦))    # 2
(pp (array/pop 待辦))    # "laundry"
(print (length 待辦))    # 1
(pp (array/pop @[]))     # nil   空的 pop 不會炸

(print "== 多層的容器：get-in、put-in ==")
(def 設定 @{:db @{:host "localhost" :port 5432}})
(pp (get-in 設定 [:db :port]))      # 5432
(pp (get-in 設定 [:db :user]))      # nil   最後一層不存在
(pp (get-in 設定 [:cache :size]))   # nil   中間那層不存在也不炸
(put-in 設定 [:db :user] "admin")
(pp (get-in 設定 [:db :user]))      # "admin"

(print "== 坑：get 的第三個參數是預設值 ==")
(pp (get 設定 :db :port))    # @{:host "localhost" :port 5432 :user "admin"}   拿到 :db 整包
(pp (get 設定 :zzz :port))   # :port   拿不到 :zzz 才回預設值 :port
(defn 兩個鍵 [t] (t :db :port))
(pp (protect (兩個鍵 設定)))   # (false "<table 0x...> called with 2 arguments, possibly expected 1")

(print "== 坑：put 超出長度會補 nil ==")
(pp (put @[1 2 3] 5 9))   # @[1 2 3 nil nil 9]

(print "== 坑：值是 false 時 get 也回假 ==")
(def 旗標 @{:debug false})
(pp (get 旗標 :debug))        # false
(pp (has-key? 旗標 :debug))   # true   問「有沒有這個鍵」用 has-key?

# ---- 練習解答 ----
(print "== 練習解答 ==")
# 1. update 加三次
(def 計數 @{:count 0})
(update 計數 :count inc)
(update 計數 :count inc)
(update 計數 :count inc)
(pp 計數)   # @{:count 3}

# 2. push 三個、pop 一個
(def 名單 @[])
(array/push 名單 "Ann")
(array/push 名單 "Bob")
(array/push 名單 "Cid")
(array/pop 名單)
(print (length 名單))   # 2

# 3. 兩層 table
(def 資料 @{:user @{:name "Bob"}})
(print (get-in 資料 [:user :name]))   # Bob
(put-in 資料 [:user :email] "bob@example.com")
(pp 資料)   # @{:user @{:email "bob@example.com" :name "Bob"}}
