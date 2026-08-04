# `--list` 印的那一大段 —— 只做字串，不 print、不 os/exit。
#
# 回字串而不是直接印，是為了讓測試可以整段拿去比對（例如「自訂的有沒有標出來源檔案」）。
# 呼叫端 (print (list-text)) 才是真的印出去。

(import ./endpoints :as ep)

(defn- vision-label [v]
  (cond (= true v) "吃圖" (= false v) "純文字" "（未標示）"))

(defn- params-label [spec]
  (def p (get spec :params))
  (if (or (nil? p) (empty? p))
    nil
    (string/join (seq [[k v] :pairs p] (string/format "%s=%q" k v)) " ")))

(defn- describe-endpoint [name spec]
  (def lines @[])
  (array/push lines
              (string/format "  %-12s model=%-16s %s" name (get spec :model)
                             (vision-label (get spec :vision?))))
  (when-let [n (get spec :note)]
    (array/push lines (string/format "               %s" n)))
  (when-let [u (get spec :url)]
    (array/push lines (string/format "               直接打：%s（不經 --base）" u)))
  (when-let [b (get spec :base)]
    (array/push lines (string/format "               base：%s" b)))
  (when-let [p (params-label spec)]
    (array/push lines (string/format "               預設參數：%s" p)))
  (when-let [h (get spec :headers)]
    (array/push lines (string/format "               額外 header：%s"
                                     (string/join (sorted (keys h)) " "))))
  (when-let [e (get spec :api-key-env)]
    (array/push lines (string/format "               金鑰讀自：%s%s" e
                                     (if (os/getenv e) "" "  ⚠ 本機未設"))))
  (array/push lines
              (string/format "               proxy 端需要的環境變數：%s%s"
                             (or (get spec :env) "（不需要）")
                             (if (ep/env-ready? name) "" "  ⚠ 本機未設")))
  lines)

(defn- config-section
  "最後那段「設定檔載到了沒」的說明。"
  []
  (if (empty? ep/loaded-files)
    (string "endpoint 設定檔：沒載到任何一份。會依序找這些位置——\n"
            (string/join (map |(string "  " $) (ep/config-candidates)) "\n")
            (if (empty? (ep/config-candidates)) "  （連 HOME 都沒設，無處可找）" "")
            "\n也可以用 --endpoints <檔案> 明確指定；範本見 modules/llm-http/endpoints.example.janet")
    (string "endpoint 設定檔：已載入\n"
            (string/join (map |(string "  " $) ep/loaded-files) "\n"))))

(defn list-text
  ``--list 印的東西，回一整段字串。

  內建與自訂分開列，自訂的會標出**是從哪個設定檔載進來的**，
  最後印 proxy base 與設定檔的探測結果。``
  []
  (def out @[])
  (def names (ep/endpoint-names))
  (def builtins (filter |(ep/builtin-endpoint? $) names))
  (def customs  (filter |(not (ep/builtin-endpoint? $)) names))

  (array/push out "內建 endpoint")
  (each n builtins (array/concat out (describe-endpoint n (get ep/specs n))))

  (if (empty? customs)
    (array/push out "\n自訂 endpoint：（沒有）")
    (do
      (array/push out "\n自訂 endpoint")
      (each n customs
        (array/concat out (describe-endpoint n (get ep/specs n)))
        (def src (ep/endpoint-source n))
        (array/push out (string/format "               來源：%s"
                                       (if (= :runtime src) "程式裡 define-endpoint 註冊的" src))))))

  (array/push out (string/format "\nproxy base：%s（LITELLM_BASE 可覆寫）" (ep/base-url)))
  (array/push out (config-section))
  (string/join out "\n"))
