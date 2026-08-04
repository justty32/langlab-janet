# llm-http 範例 ⑧ —— 錯誤處理：東西壞掉的時候長什麼樣、怎麼接。
#
# 本模組的約定：**這一層不印東西、不 os/exit，出錯一律 (error "中文訊息")**。
# 要怎麼呈現是呼叫端的決定——所以你需要 protect（或 try）把它接下來。
#
#   (def [ok v] (protect (llm/ask cfg "…")))
#   (if ok (print v) (eprint "失敗：" v))
#
# ★ 本檔**整支都不需要後端**：每一段都是「故意讓它壞」，看錯誤訊息長怎樣。
#   （有一段會刻意打一個沒人聽的 port，那也是預期中的失敗。）
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/08-errors.janet

(import ../../modules/llm-http/init :as llm)

(defn expect-fail
  ``跑一段**預期會失敗**的呼叫，把中文錯誤訊息印出來。
  成功了反而要喊一聲——代表這個 example 的假設過時了。``
  [label f]
  (printf "\n── %s ──" label)
  (def [ok v] (protect (f)))
  (if ok
    (printf "  ⚠ 居然成功了：%q（這個 example 的假設可能過時了）" v)
    (each line (string/split "\n" (string v))
      (printf "  %s" line))))

(defn main [& _]

  # ── ① endpoint 名字打錯 —— 回 nil，不是丟例外 ─────────────────────
  # ★ 這是刻意的：「查不到」是**資料**，用 nil 表示；「設定壞掉」才是例外。
  (print "── ① endpoint 名字打錯 ──")
  (def cfg (llm/endpoint "locall"))            # 多打一個 l
  (printf "  (llm/endpoint \"locall\") → %q" cfg)
  (unless cfg
    (printf "  所以自己要檢查：沒有這個 endpoint（可用：%s）"
            (string/join (llm/endpoint-names) "、")))

  # ── ② endpoint 設定缺欄位／打錯欄位 —— 丟例外，而且在打 HTTP 之前 ──
  (expect-fail "② 設定缺 :model" |(llm/endpoint {:base "http://127.0.0.1:4000"}))
  (expect-fail "② :vision? 打成 :vision" |(llm/endpoint {:model "m" :vision true}))
  (expect-fail "② :params 給錯型別" |(llm/endpoint {:model "m" :params "低溫"}))

  # ── ③ proxy／伺服器沒起來 ─────────────────────────────────────────
  # 打一個保證沒人聽的 port，看訊息長怎樣。
  (expect-fail "③ 連不上（proxy 沒起來）"
               |(llm/ask (llm/endpoint {:model "m" :base "http://127.0.0.1:45799"}) "嗨"))

  # ⚠ 相關陷阱：localhost 在這台機器會先解到 ::1，Janet 的 net/connect 只取
  #   getaddrinfo 第一筆，對只聽 IPv4 的後端會直接 connection refused。
  #   curl／litellm 有 happy-eyeballs 所以看不出差別——「curl 通但 Janet 不通」先查這條。
  (print "\n  ⚠ 一律寫 127.0.0.1 不要寫 localhost（::1 陷阱，見 FINDINGS.md 第五節）。")
  (print "  ⚠ spork/http 沒有 TLS，:url 寫 https:// 一定打不通，不是設定寫錯。")

  # ── ④ 設定檔壞掉 ──────────────────────────────────────────────────
  (def dir (or (os/getenv "TMPDIR") "/tmp"))
  (expect-fail "④ 設定檔不存在"
               |(llm/load-endpoints! (string dir "/根本沒這個檔.janet")))

  (def broken (string dir "/llm-http-example-broken.janet"))
  (spit broken `{"a" {:model "x"}`)             # 少一個右括號
  (expect-fail "④ 設定檔括號少收" |(llm/load-endpoints! broken))
  (os/rm broken)

  (def not-data (string dir "/llm-http-example-notdata.janet"))
  (spit not-data `(def x 1)`)                   # 寫成程式而不是資料
  (expect-fail "④ 設定檔寫成程式碼" |(llm/load-endpoints! not-data))
  (os/rm not-data)

  (def bad-spec (string dir "/llm-http-example-badspec.janet"))
  (spit bad-spec `{"我的" {:base "http://127.0.0.1:4000"}}`)
  (expect-fail "④ 設定檔裡某一筆缺 :model" |(llm/load-endpoints! bad-spec))
  (os/rm bad-spec)

  # ⚠ 但「**沒有**設定檔」不是錯誤：autoload 完全不會吭聲
  (printf "\n── ⑤ 沒有設定檔是正常狀態 ──")
  (printf "  (autoload-endpoints!) → %q（找不到就靜靜回 nil，不報錯）"
          (llm/autoload-endpoints!))

  # ── ⑥ 模型不吃圖 ──────────────────────────────────────────────────
  # 這個**不會**在本地報錯——:vision? 只是一個標記，真的送出去才知道會怎樣
  # （從報錯到靜默無視都有可能）。所以自己先檢查。
  (print "\n── ⑥ 模型不吃圖 ──")
  (each n ["local" "deepseek"]
    (def c (llm/endpoint n))
    (printf "  %-9s :vision? = %q → %s" n (c :vision?)
            (cond
              (= false (c :vision?)) "⚠ 別送圖，可能報錯、也可能被靜默無視"
              (= true (c :vision?))  "可以送圖"
              "沒表態（自訂 endpoint 沒寫 :vision? 就是這樣，送之前自己確認）")))

  # ── ⑦ 回應裡沒有答案文字 ──────────────────────────────────────────
  # 例如模型只回了 tool_calls（content 是 nil）。ask 會丟例外，
  # chat ＋ reply-text 則是回 nil，讓你自己判斷。
  (print "\n── ⑦ 回應裡沒有答案文字 ──")
  (def fake-res {:choices [{:message {:role "assistant" :tool_calls []}}]})
  (printf "  (reply-text 回應) → %q（取不到就是 nil，不丟例外）" (llm/reply-text fake-res))
  (print "  ask 遇到這種情況會丟「回應裡取不出答案文字：…」，因為它承諾回字串。")

  # ── ⑧ tool loop 撞到上限 ──────────────────────────────────────────
  (print "\n── ⑧ tool loop 撞到 max-rounds ──")
  (print "  with-tools 回的表裡 :exhausted 為 true、:text 是 nil ——")
  (print "  這是**資料**不是例外，因為「模型鬼打牆」不見得算錯誤，由你決定怎麼辦。")

  (print "\n★ 總結：查不到 → nil；設定壞掉／連不上／HTTP 非 2xx → 例外（中文訊息）；")
  (print "  沒有設定檔、撞到 max-rounds → 都不算錯誤。"))
