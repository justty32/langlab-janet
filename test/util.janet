# 測試共用的小工具。
#
# ⚠ jpm test 會把 test/ 底下**每一支** .janet 都當測試跑一遍，所以這支被單獨執行時
#   什麼都不做（只有定義），這是正常的、也是刻意的——不要在這裡放會印東西的程式碼。

(defn err-of
  ``跑 f，斷言它一定失敗，把錯誤訊息當字串回傳。

  用來驗「錯誤訊息是不是看得懂的中文」：
    (assert (string/find "缺 :model" (err-of |(llm/endpoint {:base "http://x"}))))``
  [f]
  (def [ok e] (protect (f)))
  (assert (not ok) "這個呼叫本來就該失敗")
  (string e))
