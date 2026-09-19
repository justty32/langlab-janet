# sandbox —— 「這條路徑可不可以碰」只在這裡判斷。檔案工具（tools-fs／tools-search）都先問它。
#
# 規則：
#   * root 在建立時就 os/realpath 成絕對路徑（root 必須存在）
#   * 相對路徑 = 相對 root；絕對路徑也收，但必須落在 root 底下
#   * 正規化之後（吃掉 . 與 ..）不在 root 底下 → 拒絕（丟中文錯誤）
#   * 已存在的路徑再 os/realpath 一次，**symlink 指到外面**也擋得住
#   * 寫入預設關閉（:write? false）；要開得在 make-sandbox 明講
#
# ⚠ path/join "/root" "/etc/passwd" 會得到 "/root/etc/passwd"（spork 不會因為第二段是
#   絕對路徑就丟掉前面），所以絕對路徑要自己分開處理，不能一律 join。

(import spork/path)

(defn make-sandbox
  ``建一個 sandbox：root 是允許碰的根目錄（要存在），:write? 沒給就是 false。
    (make-sandbox ".")                 # 只讀
    (make-sandbox "/tmp/work" :write? true)``
  [root &named write?]
  (def [ok real] (protect (os/realpath (string root))))
  (unless ok (error (string "sandbox 的根目錄不存在或讀不到：" root)))
  (unless (= :directory (os/stat real :mode))
    (error (string "sandbox 的根目錄不是資料夾：" real)))
  @{:root real :write? (truthy? write?)})

(defn inside?
  "一條**已正規化的絕對路徑**是不是在 root 底下（root 自己也算）。"
  [sb abs]
  (def root (sb :root))
  (or (= abs root) (string/has-prefix? (string root "/") abs)))

(defn- refuse [sb p]
  (error (string "拒絕：路徑「" p "」跳出了允許的根目錄 " (sb :root))))

(defn resolve-path
  ``把模型給的路徑解成 root 底下的絕對路徑；跳出去就丟錯。
  只做字串層的檢查（不要求存在）；要防 symlink 用 resolve-existing。``
  [sb p]
  (def s (string (or p "")))
  (when (empty? s) (error "路徑是空的"))
  (def abs (path/normalize (if (path/abspath? s) s (path/join (sb :root) s))))
  (unless (inside? sb abs) (refuse sb s))
  abs)

(defn resolve-existing
  ``resolve-path 再加一道：路徑要存在，而且 os/realpath 之後仍在 root 底下
  （擋掉「root 裡放一個指到 /etc 的 symlink」這招）。``
  [sb p]
  (def abs (resolve-path sb p))
  (def [ok real] (protect (os/realpath abs)))
  (unless ok (error (string "找不到：" p)))
  (unless (inside? sb real) (refuse sb p))
  real)

(defn resolve-for-write
  ``寫檔用：sandbox 要開 :write?，目標的**上層資料夾**要存在且 realpath 後仍在 root 底下。
  目標檔本身可以不存在（新建）。``
  [sb p]
  (unless (sb :write?)
    (error "拒絕：這個 sandbox 沒有開放寫入（make-sandbox … :write? true 才會開）"))
  (def abs (resolve-path sb p))
  (def parent (path/dirname abs))
  (def [ok real-parent] (protect (os/realpath parent)))
  (unless ok (error (string "上層資料夾不存在：" parent)))
  (unless (inside? sb real-parent) (refuse sb p))
  (path/join real-parent (path/basename abs)))

(defn display-path
  "把絕對路徑印成相對 root 的樣子（給模型看比較短，也不洩漏本機目錄結構）。"
  [sb abs]
  (if (= abs (sb :root)) "." (path/relpath (sb :root) abs)))
