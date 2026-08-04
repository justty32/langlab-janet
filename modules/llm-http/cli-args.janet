# 把 argparse 的結果**翻譯成模組吃得下的東西** —— 全是純函式，測試直接叫。
#
# 這一層負責的是「命令列的字串」→「Janet 的值」：k=v 怎麼切、"0.2" 什麼時候
# 該變成數字、--url/--model 怎麼組成一個臨時 endpoint。不碰網路、不 os/exit。

# ★ 這裡 import 的是 endpoints.janet（門面）不是 registry.janet：
#   門面才會觸發「自動探測使用者設定檔」那一步，CLI 需要它。
(import ./endpoints :as ep)

(defn coerce-value
  ``把命令列上的字串值轉成該有的型別：數字→數字，true/false/null→對應的值，
  其餘原樣當字串。刻意**不**做 JSON 解析——要送結構化的東西請走函式庫那條路。``
  [s]
  (cond
    (= s "true")  true
    (= s "false") false
    (= s "null")  nil
    (if-let [n (scan-number s)] n s)))

(defn parse-kv
  ``把 "名字<sep>值" 切成 [名字 值]；沒有分隔符就丟中文錯誤。
  只切第一個分隔符，所以值裡面還可以有分隔符（header 的 URL 值就靠這個）。``
  [s sep label]
  (def i (string/find sep s))
  (unless i
    (error (string/format "%s 的格式要是「名字%s值」，收到：%s" label sep s)))
  [(string/trim (string/slice s 0 i))
   (string/trim (string/slice s (+ i (length sep))))])

(defn param-table
  "把一串 \"k=v\" 轉成請求參數表（key 是 keyword，值會做型別轉換）。"
  [strings]
  (def out @{})
  (each s (or strings @[])
    (def [k v] (parse-kv s "=" "--param"))
    (when (empty? k) (error (string "--param 的名字是空的：" s)))
    (put out (keyword k) (coerce-value v)))
  out)

(defn header-table
  "把一串 \"名字:值\" 轉成 header 表（key／值都是字串）。"
  [strings]
  (def out @{})
  (each s (or strings @[])
    (def [k v] (parse-kv s ":" "--header"))
    (when (empty? k) (error (string "--header 的名字是空的：" s)))
    (put out k v))
  out)

(defn request-params
  ``把命令列上的參數旗標整理成一張請求參數表。

  合併順序：--param ＜ --temperature／--max-tokens／--top-p
  （專用旗標比通用的 --param 具體，所以蓋得掉它）。
  這張表最後是以 chat 的 :params 送出去的，所以會**蓋掉 endpoint 自己的 :params**。``
  [res]
  (def out (param-table (res "param")))
  (def num
    (fn [flag]
      (when-let [v (res flag)]
        (or (scan-number v)
            (error (string/format "--%s 要是數字，收到：%s" flag v))))))
  (when-let [v (num "temperature")] (put out :temperature v))
  (when-let [v (num "max-tokens")]  (put out :max_tokens v))
  (when-let [v (num "top-p")]       (put out :top_p v))
  out)

(defn load-config-files!
  "把 --endpoints 指的設定檔一份份載進 registry；載不動會丟中文錯誤。"
  [res]
  (each p (or (res "endpoints") @[])
    (ep/load-endpoints! p)))

(defn resolve-endpoint
  ``依名字（或臨時參數）組出可以打的 cfg；組不出來回 nil，由呼叫端決定怎麼報錯。

  ① 名字在 registry 裡 → 拿它，再把命令列的覆寫疊上去
  ② 名字不在 registry，但有給 --url／--base ＋ --model → 當場組一個臨時 endpoint
  ③ 其餘 → nil``
  [res name]
  (def overrides @{})
  (when-let [v (res "model")]   (put overrides :model v))
  (when-let [v (res "base")]    (put overrides :base v))
  (when-let [v (res "url")]     (put overrides :url v))
  (when-let [v (res "api-key")] (put overrides :api-key v))
  (def hs (header-table (res "header")))
  (unless (empty? hs) (put overrides :headers hs))

  (cond
    (get ep/specs name) (ep/endpoint name overrides)
    (and (or (res "url") (res "base")) (res "model"))
    (ep/endpoint {:name name :model (res "model")} overrides)))
