# 把一份 endpoint 設定**組成可以直接打的 cfg** —— endpoint／env-ready? 住在這裡。
#
# registry.janet 只管「表裡有誰」，這支管「拿到之後怎麼變成 chat 吃得下的東西」：
# :url 怎麼決定、金鑰從哪來、overrides 怎麼疊。這兩件事會分開，是因為
# 組 cfg 的規則（尤其是合併優先序）是最常被問、最需要單獨讀懂的一段。

(import ./defaults :as d)
(import ./registry :as reg)
(import ./spec :as sp)

(defn- merge-dicts
  "把兩張表疊起來回一張新的（後者蓋前者）；兩邊都沒東西就回 nil。"
  [a b]
  (if (and (nil? a) (nil? b))
    nil
    (let [out @{}]
      (when a (eachp [k v] a (put out k v)))
      (when b (eachp [k v] b (put out k v)))
      out)))

# overrides 裡這幾個 key 有專門的處理，不要原樣塞進 cfg
(def- special-override-keys [:base :params :headers :api-key-env])

(defn- build-cfg
  [name spec overrides]
  (def ov (or overrides {}))

  # ── :url 的決定順序（先到先贏）──────────────────────────────────
  #   overrides :url  >  overrides :base  >  spec :url  >  spec :base  >  預設 base
  (def url
    (cond
      (get ov :url)   (string (get ov :url))
      (get ov :base)  (d/chat-url (get ov :base))
      (get spec :url) (string (get spec :url))
      (d/chat-url (get spec :base))))

  # ── :api-key 的決定順序 ─────────────────────────────────────────
  #   overrides :api-key > overrides :api-key-env > spec :api-key > spec :api-key-env > proxy-key
  (def api-key
    (or (get ov :api-key)
        (when-let [v (get ov :api-key-env)] (os/getenv v))
        (get spec :api-key)
        (when-let [v (get spec :api-key-env)] (os/getenv v))
        (d/proxy-key)))

  (def cfg @{:name    name
             :model   (get spec :model)
             :url     url
             :api-key api-key
             :env     (get spec :env)
             :vision? (get spec :vision?)
             :note    (get spec :note)})

  # :params／:headers 是**疊加**不是取代（同名以 overrides 為準）
  (when-let [p (merge-dicts (get spec :params) (get ov :params))]
    (put cfg :params p))
  (when-let [h (merge-dicts (get spec :headers) (get ov :headers))]
    (put cfg :headers h))

  # 其餘 overrides 原樣蓋上去（最常用的是 :model）
  (eachp [k v] ov
    (unless (index-of k special-override-keys) (put cfg k v)))
  cfg)

(defn endpoint
  ``取一份**全新的** endpoint 設定 table，可以直接餵給 chat／ask／with-tools。

  第一個參數兩種吃法：

    ① 名字字串 —— 去 registry 找，**沒這個名字回 nil**（維持舊行為）
         (endpoint "local")
         (endpoint "local" {:model "qwen"})
         (endpoint "deepseek" {:base "http://127.0.0.1:4111"})

    ② 直接給一張 table／struct —— 不必註冊，當場就是一個 endpoint
         (endpoint {:model "qwen3" :base "http://127.0.0.1:4000" :vision? true})
         (endpoint {:model "qwen3" :url "http://127.0.0.1:1234/v1/chat/completions"})
       ⚠ 這條會**驗證**設定，缺 :model 之類的問題會當場丟中文錯誤（不是回 nil）。

  回傳的 table 至少含 :name :model :url :api-key，另外可能有 :params :headers
  :env :vision? :note。

  overrides 的合併規則：
    :base            拿來組 :url（給了 :url 就不看它）
    :params/:headers **疊加**在 endpoint 自己那份上面，同名以 overrides 為準
    其他 key         原樣蓋上去

  ★ 每次都重新組一份，所以 overrides 不會污染下一次呼叫。``
  [what &opt overrides]
  (cond
    (bytes? what)
    (let [name (string what)
          spec (get reg/specs name)]
      (when spec (build-cfg name spec overrides)))

    (dictionary? what)
    (let [name (or (get what :name) "（inline）")]
      (build-cfg name (sp/normalize-spec what name) overrides))

    (error (string/format
             "endpoint 的第一個參數要嘛是名字字串、要嘛是一張設定 table，收到的是 %s"
             (type what)))))

(defn env-ready?
  ``這條線需要的環境變數有沒有設；不需要金鑰的（或不認得的名字）一律回 true。

  檢查兩個欄位：
    :env         proxy **那端**需要的變數（例如 DEEPSEEK_API_KEY）
    :api-key-env 本模組自己要讀來當 Bearer token 的變數

  ⚠ 只是本機探測，proxy 可能跑在別的環境裡，僅供 --list 提示用。
  參數可以給名字字串，也可以直接給一份設定 table。``
  [name-or-spec]
  (def spec (if (bytes? name-or-spec)
              (get reg/specs (string name-or-spec))
              name-or-spec))
  (if-not (dictionary? spec)
    true
    (all (fn [k] (if-let [v (get spec k)] (truthy? (os/getenv v)) true))
         [:env :api-key-env])))
