# endpoint 設定的**驗證與正規化** —— 純函式，不碰 registry、不碰網路、不碰檔案。
#
# 「一份 endpoint 設定長什麼樣才算合法」這件事只在這裡定義。分出來的好處是：
# registry（誰在表裡）、resolve（怎麼組成可以打的 cfg）、config（從檔案讀進來）
# 三邊都拿這支當同一把尺，錯誤訊息也只有一種寫法。
#
# ★ 驗證一律**在打 HTTP 之前**就爆，而且是看得懂的中文——不要讓使用者等到
#   connection refused 或 400 才發現自己 :model 打錯字。

(def spec-keys
  "一份 endpoint 設定認得的欄位（欄位意義見 builtin.janet 的 builtin-specs docstring）。
  拼錯欄位名會在驗證時被擋下來，不會靜靜被忽略。"
  [:model :base :url :api-key :api-key-env :headers :params :env :vision? :note :name])

(defn- fail
  "統一的中文錯誤出口：只丟訊息，不留 Janet 的 stacktrace 味道。"
  [fmt & args]
  (error (string/format fmt ;args)))

(defn- dict-of-strings?
  "檢查是不是一張「值都是字串／數字」的表（給 :headers 用）。"
  [t]
  (and (dictionary? t)
       (all (fn [[_ v]] (or (bytes? v) (number? v))) (pairs t))))

(defn normalize-spec
  ``驗證一份 endpoint 設定並補上預設，回一份**全新的** table；有問題就丟中文錯誤。

  label 只是錯誤訊息裡的稱呼（endpoint 名字或「inline」），不影響結果。

  驗證的東西：
    * 必須是 table／struct
    * :model 必填且是字串
    * :base／:url／:api-key／:api-key-env 若有給必須是字串
    * :headers／:params 若有給必須是表
    * 不認得的欄位一律擋下（拼錯 :vision? 成 :vision 這種最容易靜靜出錯）``
  [spec &opt label]
  (default label "（未命名）")
  (unless (dictionary? spec)
    (fail "endpoint「%s」的設定必須是一張 table 或 struct，收到的是 %s"
          label (type spec)))

  (def unknown (filter |(not (index-of $ spec-keys)) (keys spec)))
  (unless (empty? unknown)
    (fail "endpoint「%s」的設定有不認得的欄位：%s\n可用欄位：%s"
          label
          (string/join (map |(string/format "%q" $) (sorted unknown)) "、")
          (string/join (map |(string/format "%q" $) spec-keys) " ")))

  (def model (get spec :model))
  (cond
    (nil? model)
    (fail "這份 endpoint 設定缺 :model —— endpoint「%s」必須指明送給 proxy／伺服器的 model 名稱，例如 {:model \"local\"}"
          label)
    (not (bytes? model))
    (fail "endpoint「%s」的 :model 必須是字串，收到 %s（%q）" label (type model) model))

  (each k [:base :url :api-key :api-key-env]
    (when-let [v (get spec k)]
      (unless (bytes? v)
        (fail "endpoint「%s」的 %q 必須是字串，收到 %s" label k (type v)))))

  (when-let [p (get spec :params)]
    (unless (dictionary? p)
      (fail "endpoint「%s」的 :params 必須是一張表，像 {:temperature 0.2 :max_tokens 512}，收到 %s"
            label (type p))))

  (when-let [h (get spec :headers)]
    (unless (dict-of-strings? h)
      (fail "endpoint「%s」的 :headers 必須是一張表，像 {\"x-my-header\" \"v\"}，值要是字串"
            label)))

  (def out @{:model   (string model)
             :env     (get spec :env)
             :vision? (get spec :vision?)
             :note    (get spec :note)})
  (each k [:base :url :api-key :api-key-env]
    (when-let [v (get spec k)] (put out k (string v))))
  (when-let [p (get spec :params)]  (put out :params  (table ;(kvs p))))
  (when-let [h (get spec :headers)] (put out :headers (table ;(kvs h))))
  out)
