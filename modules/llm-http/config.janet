# endpoint 設定檔的載入 —— 讓使用者不必改 repo、也不必把自己的設定 commit 進來。
#
# ★ 只 **parse** 不 **eval**：檔案內容是一份 Janet **資料字面值**，用 parse-all 讀進來。
#   使用者的設定檔不會被當程式執行，所以裡面寫 (os/shell "rm -rf /") 也只是一個 tuple。
#   （想跑程式的人自己 dofile，那是他的決定，不是本模組替他做的。）
#
# ── 檔案長怎樣 ──────────────────────────────────────────────────────
#   最外層是一張表：名字 → 設定。範本見同目錄的 endpoints.example.janet。
#
#     {"qwen"     {:model "qwen3" :params {:temperature 0.2}}
#      "lmstudio" {:model "google/gemma-4-e4b"
#                  :url   "http://127.0.0.1:1234/v1/chat/completions"}}
#
#   檔案裡可以有**多個** top-level 的表，會依序疊加（後面的蓋前面的）。
#   副檔名是 .json 的話改走 spork/json（最外層的 key 會被當成 endpoint 名字）。
#
# ── 自動探測順序 ────────────────────────────────────────────────────
#   ① 環境變數 LLM_HTTP_ENDPOINTS 指的檔案
#   ② $XDG_CONFIG_HOME/llm-http/endpoints.janet
#   ③ ~/.config/llm-http/endpoints.janet
#   **找不到就靜靜跳過**（沒有設定檔是正常狀態，絕不報錯）；
#   找到了但格式壞掉會在 stderr 印一行看得懂的中文警告，然後照樣讓程式跑下去。

(import spork/json)
(import ./registry :as reg)

(def loaded-files
  "這個行程裡成功載入過的設定檔路徑（依載入順序）。--list 會印出來。"
  @[])

(defn- fail
  [fmt & args]
  (error (string/format fmt ;args)))

(defn- read-text
  "把設定檔整份讀成字串；不存在／讀不到都給看得懂的中文錯誤。"
  [path]
  (unless (os/stat path :mode)
    (fail "找不到 endpoint 設定檔：%s" path))
  (def [ok content] (protect (slurp path)))
  (unless ok
    (fail "讀不到 endpoint 設定檔 %s：%s" path content))
  (string content))

(defn- stringify-keys
  "把最外層的 key 一律轉成字串（JSON 解出來會是 keyword，Janet 那條可能寫成 symbol）。"
  [t]
  (def out @{})
  (eachp [k v] t
    (put out (if (bytes? k) (string k) (string/format "%s" k)) v))
  out)

(defn parse-endpoints
  ``把一段設定檔文字解成「名字 → 設定」的表；**只 parse 不 eval**。

  json? 為真時走 spork/json，否則走 Janet 的 parse-all。
  label 只用在錯誤訊息裡（通常給檔名）。``
  [text &opt json? label]
  (default label "（字串）")
  (def out @{})

  (if json?
    (let [[ok v] (protect (json/decode text true))]
      (unless ok
        (fail "endpoint 設定檔 %s 不是合法的 JSON：%s" label v))
      (unless (dictionary? v)
        (fail "endpoint 設定檔 %s 的最外層應該是一個物件（名字 → 設定），收到的是 %s"
              label (type v)))
      (eachp [k spec] (stringify-keys v) (put out k spec)))

    (let [[ok forms] (protect (parse-all text))]
      (unless ok
        (fail (string "endpoint 設定檔 %s 格式有誤，不是合法的 Janet 資料字面值：%s\n"
                      "提示：內容應該是一張表，像 {\"名字\" {:model \"…\"}}；括號有沒有少收一個？")
              label forms))
      (when (empty? forms)
        (fail "endpoint 設定檔 %s 是空的（至少要有一張 {\"名字\" {:model \"…\"}} 的表）" label))
      (each form forms
        (unless (dictionary? form)
          (fail (string "endpoint 設定檔 %s 的最外層應該是一張表（名字 → 設定），"
                        "收到的是 %s\n提示：這個檔案是**資料**不是程式，不要寫 (def …)／(import …)。")
                label (type form)))
        (eachp [k spec] (stringify-keys form) (put out k spec)))))
  out)

(defn load-endpoints!
  ``從設定檔把使用者的 endpoint 讀進 registry，回傳載入的名字陣列（排序過）。

    (load-endpoints! "~/我的/endpoints.janet")

  副檔名 .json 走 JSON，其餘走 Janet 資料字面值。
  ⚠ 這是**明確要求**載入的入口，所以檔案不存在／格式壞／設定不合法一律丟中文錯誤。
  想要「有就載、沒有就算了」請用 autoload-endpoints!。``
  [path &opt json?]
  (def p (string path))
  (default json? (string/has-suffix? ".json" (string/ascii-lower p)))
  (def entries (parse-endpoints (read-text p) json? p))
  (def names @[])
  (eachp [name spec] entries
    # define-endpoint 自己會驗證；把檔名補進錯誤訊息，才知道要去改哪一份
    (def [ok e] (protect (reg/define-endpoint name spec p)))
    (unless ok
      (fail "endpoint 設定檔 %s 裡的「%s」設定有問題：\n  %s" p name e))
    (array/push names (string name)))
  (unless (index-of p loaded-files) (array/push loaded-files p))
  (sorted names))

(defn config-candidates
  ``自動探測會依序看的路徑（只回「可能的位置」，不管檔案在不在）。

  順序：LLM_HTTP_ENDPOINTS → $XDG_CONFIG_HOME/llm-http/endpoints.janet
        → ~/.config/llm-http/endpoints.janet``
  []
  (def out @[])
  (def push-env
    (fn [var suffix]
      (when-let [v (os/getenv var)]
        (unless (empty? v)
          (array/push out (if suffix (string v suffix) v))))))
  (push-env "LLM_HTTP_ENDPOINTS" nil)
  (push-env "XDG_CONFIG_HOME" "/llm-http/endpoints.janet")
  (push-env "HOME" "/.config/llm-http/endpoints.janet")
  out)

(defn autoload-endpoints!
  ``自動探測並載入第一份找得到的設定檔；回傳它的路徑，都找不到就回 nil。

  ★ 沒有設定檔是**正常狀態**，這裡絕不報錯、也不印任何東西。
  ★ 找到了但格式壞掉／設定不合法，會在 stderr 印一行中文警告，然後當作沒載入
    ——因為一份壞掉的設定檔不該讓「只想打內建 local」的人整個跑不起來。``
  []
  (var hit nil)
  (each path (config-candidates)
    (when (and (nil? hit) (os/stat path :mode))
      (def [ok e] (protect (load-endpoints! path)))
      (if ok
        (set hit path)
        (eprintf "⚠ endpoint 設定檔載入失敗，已略過：%s" e))))
  hit)
