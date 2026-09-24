# 配合 course/11-4-todo-測試與打包.md：測試共用的小工具。
# ⚠ jpm test 會把 test/ 底下每一支都跑一遍，所以這支只有定義、不印東西，被單獨跑也沒事。

(defn temp-dir
  ``開一個專門給這次測試用的暫存目錄，回傳路徑。
  測試絕對不能碰 repo 裡的檔案，也不能碰使用者真的在用的 todo.json。``
  [tag]
  (def base (os/getenv "TMPDIR" "/tmp"))
  (def dir (string base "/todo-test-" tag "-" (os/time) "-" (math/floor (* 1000 (math/random)))))
  (os/mkdir dir)
  dir)

(defn cleanup
  "把暫存目錄和裡面的檔案清掉（目錄不空 os/rm 會失敗，所以先刪檔）。"
  [dir]
  (each name (os/dir dir) (os/rm (string dir "/" name)))
  (os/rm dir))

(defn err-of
  "跑 f，斷言它一定拋錯，回傳錯誤訊息字串（拿來檢查訊息看不看得懂）。"
  [f]
  (def [ok e] (protect (f)))
  (assert (not ok) "這個呼叫本來就該失敗")
  (string e))
