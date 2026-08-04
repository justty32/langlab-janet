# endpoint registry —— 「表裡有哪些 endpoint」這一件事，只管註冊與查詢。
#
# endpoint 那塊拆成五支檔，各管一件事：
#   builtin.janet   內建四筆的**資料**（不可變）
#   spec.janet      一份設定合不合法（純函式驗證）
#   registry.janet  本檔：誰在表裡（註冊／移除／重設／查來源）
#   resolve.janet   把設定組成**可以打的 cfg**（endpoint／env-ready?）
#   config.janet    從**設定檔**把使用者的 endpoint 讀進來（parse，不 eval）
#
# ── 使用者要加自己的 endpoint 有三條路 ──────────────────────────────
#   ① 完全不註冊，直接把一張 table 當 endpoint 用（見 resolve.janet 的 endpoint）：
#        (endpoint {:model "qwen3" :base "http://127.0.0.1:4000"})
#   ② 註冊成有名字的，之後照舊用名字取：
#        (define-endpoint "qwen" {:model "qwen3" :params {:temperature 0.2}})
#        (endpoint "qwen")
#   ③ 寫進設定檔，自動載入（見 config.janet 與 endpoints.example.janet）
#
# ★ specs 是一張**活的 table**（不是以前的 struct）：內建四筆先躺在裡面，
#   define-endpoint／設定檔載入會往裡面加。舊寫法 (get specs "local")／(keys specs)
#   語意不變，而且現在連使用者自訂的也看得到。

(import ./builtin :as b)
(import ./spec :as sp)

(def specs
  ``活的 endpoint registry：名字（字串）→ 設定。內建四筆先在裡面。

  讀法跟以前完全一樣：(get specs "local")、(keys specs)。
  ⚠ 跟舊版的差別只有一個：它現在是 table 不是 struct，而且會長出使用者自訂的 endpoint。
  只想看內建那四筆請用 builtin/builtin-specs（那份仍然是不可變的 struct）。``
  (table ;(kvs b/builtin-specs)))

(def sources
  ``名字 → 這筆 endpoint 是打哪來的：
    :builtin  內建
    :runtime  程式裡呼叫 define-endpoint 註冊的
    "路徑"    從那個設定檔載進來的``
  (table ;(mapcat |[$ :builtin] (keys b/builtin-specs))))

(defn define-endpoint
  ``註冊（或覆蓋）一個有名字的 endpoint，回傳驗證＋正規化之後的設定。

    (define-endpoint "qwen" {:model "qwen3" :params {:temperature 0.2}})
    (endpoint "qwen")

  source 是「這筆打哪來的」標記，給 --list 顯示用；自己呼叫時通常不用給。
  ⚠ 設定不合法會直接丟中文錯誤，不會等到真的打 HTTP 才炸。``
  [name spec &opt source]
  (default source :runtime)
  (def key (string name))
  (def clean (sp/normalize-spec spec key))
  (put specs key clean)
  (put sources key source)
  clean)

(defn undefine-endpoint!
  "把一個 endpoint 從 registry 拿掉（連內建的也拿得掉）。回傳有沒有真的拿掉東西。"
  [name]
  (def key (string name))
  (def had (truthy? (get specs key)))
  (put specs key nil)
  (put sources key nil)
  had)

(defn reset-endpoints!
  "把 registry 打回「只剩內建四筆」的狀態。測試與 REPL 裡很好用。"
  []
  (each k (keys specs) (put specs k nil) (put sources k nil))
  (eachp [k v] b/builtin-specs
    (put specs k v)
    (put sources k :builtin))
  specs)

(defn endpoint-names
  "registry 裡所有 endpoint 的名字（排序過，方便印說明）。"
  []
  (sorted (keys specs)))

(defn builtin-names
  "內建那四個的名字（排序過）。"
  []
  (sorted (keys b/builtin-specs)))

(defn builtin-endpoint?
  "這個名字是不是內建的（相對於使用者自訂／設定檔載入的）。"
  [name]
  (= :builtin (get sources (string name))))

(defn endpoint-source
  "這個 endpoint 打哪來：:builtin／:runtime／設定檔路徑字串；沒這個名字回 nil。"
  [name]
  (get sources (string name)))
