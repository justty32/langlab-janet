# llm-http 範例 ⑦ —— 請求參數的覆寫與合併優先序。
#
# 一個 endpoint 可以帶「這條線的預設請求參數」（:params），呼叫端再一層層蓋上去。
# 優先序（低 → 高，後面的蓋前面的）：
#
#   ① endpoint 的 :params      {:model "…" :params {:temperature 0.2}}
#   ② chat／ask 的 :params      這次呼叫整批帶的參數
#   ③ 具名參數 :temperature 等   最常用、最具體
#   ④ :extra                    原樣併進 payload，什麼都蓋得掉
#
# ★ build-payload 是**純函式**：不連線也能把最終 payload 印出來，
#   所以本檔前半段完全離線就跑得完，很適合拿來確認自己的理解對不對。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   前半段（印 payload）不需要任何後端。最後「真的送出去」那段才需要
#   OpenAI 相容伺服器（預設 litellm proxy http://127.0.0.1:4000）。
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/07-params.janet

(import ../../modules/llm-http/init :as llm)

(def hint "\n提示：後端沒起來。先起 litellm proxy（見 01-minimal.janet 檔頭），位址用 127.0.0.1。")

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)                       # ★ 先把 stdout 吐出來，錯誤才不會插隊到前面
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

(defn show-payload
  ``把 payload 裡的參數欄位排序印出來（:messages 太長，只印筆數）。``
  [label payload]
  (printf "\n%s" label)
  (each k (sorted (filter |(not= $ :messages) (keys payload)))
    (printf "    %-14s %q" k (get payload k)))
  (printf "    %-14s（%d 則）" :messages (length (payload :messages))))

(def messages @[@{:role "user" :content "嗨"}])

(defn main [& _]
  # 這條線自己帶三個預設參數
  (def cfg (llm/endpoint {:model  "local"
                          :params {:temperature 0.2 :max_tokens 512 :top_p 0.9}}))

  (print "endpoint 自己帶的 :params ＝ temperature 0.2、max_tokens 512、top_p 0.9")

  # ① 什麼都不覆寫 → 就用 endpoint 的
  (show-payload "① 什麼都不給：" (llm/build-payload cfg messages))

  # ② :params 整批覆寫（key 用 payload 的原名，snake_case）
  (show-payload "② 加 :params {:temperature 0.5}：蓋掉 ①，沒提到的保留"
                (llm/build-payload cfg messages :params {:temperature 0.5}))

  # ③ 具名參數比 :params 具體 —— 注意這裡是 kebab-case 的 :max-tokens
  (show-payload "③ 再加具名 :temperature 0.9 :max-tokens 64：蓋掉 ②"
                (llm/build-payload cfg messages
                                   :params {:temperature 0.5}
                                   :temperature 0.9 :max-tokens 64))

  # ④ :extra 原樣併入，優先序最高；也能塞沒有具名參數的欄位
  (show-payload "④ 再加 :extra {:temperature 1.0 :seed 7 :stop [\"。\"]}：全部蓋掉"
                (llm/build-payload cfg messages
                                   :params {:temperature 0.5}
                                   :temperature 0.9 :max-tokens 64
                                   :extra {:temperature 1.0 :seed 7 :stop ["。"]}))

  # ⚠ 幾個容易搞混的點
  (print "\n── ⚠ 幾個容易搞混的點 ──")
  (print "  * :params／:extra 的 key 用 **payload 的原名**（:max_tokens、:top_p）；")
  (print "    具名參數才是 Janet 習慣的 kebab-case（:max-tokens、:top-p）。")
  (show-payload "  * temperature 0 是有效值，不會被當成「沒給」："
                (llm/build-payload cfg messages :temperature 0))
  (print "  * :model 永遠來自 cfg，塞進 :params 也沒用——換 model 請用")
  (print "    (endpoint \"local\" {:model \"qwen\"})。")

  # overrides 的 :params 是**疊加**到 endpoint 那份上面，不是整個換掉
  (def merged (llm/endpoint {:model "m" :params {:temperature 0.2 :max_tokens 512}}
                            {:params {:max_tokens 64}}))
  (printf "\n  * endpoint 的 overrides :params 是**疊加**：%q"
          (merged :params))

  # ── 真的送出去，看參數有沒有生效 ──────────────────────────────────
  (print "\n── 真的送出去 ──")
  (def real (llm/endpoint "local" {:params {:temperature 0 :max_tokens 32}}))
  (print "用 temperature 0（盡量不隨機）＋ max_tokens 32 問同一句兩次，答案應該一樣：")
  (var ok? true)
  (def answers @[])
  (repeat 2
    (when ok?
      (if-let [a (attempt "低溫問答" |(llm/ask real "從 1 數到 5，只給數字。"))]
        (array/push answers a)
        (set ok? false))))
  (when (= 2 (length answers))
    (printf "  第一次：%s" (first answers))
    (printf "  第二次：%s" (get answers 1))
    (printf "  一樣嗎？%s" (if (= (first answers) (get answers 1))
                             "是（temperature 0 生效）"
                             "否（有些後端／模型不保證完全決定性，這不算壞）")))

  # ⚠ OpenRouter 的坑
  (print "\n⚠ OpenRouter 那條線特別注意：不同模型的 supported_parameters 不一樣，")
  (print "  送了它不支援的參數（response_format／top_p／seed…）**不會報錯、就是被無視**，")
  (print "  你會拿到 exit 0 加一份看起來像答案的東西。只能看回應內容判斷。"))
