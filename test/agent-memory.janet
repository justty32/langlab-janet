# agent：記憶——append、粗估 token、整輪截斷（不拆散 tool_calls 配對）、save/load round-trip。

(import ../modules/agent/init :as ag)
(import ./util :as u)

(defn roles [m] (map |($ :role) (ag/messages m)))
(defn user [t] @{:role "user" :content t})
(defn asst [t] @{:role "assistant" :content t})
(defn call [id] @{:role "assistant" :content nil
                  :tool_calls @[@{:id id :type "function"
                                  :function @{:name "calc" :arguments `{"expression":"1+1"}`}}]})
(defn tool [id] @{:role "tool" :tool_call_id id :content "2"})

# ── 基本 ────────────────────────────────────────────────────────────
(def m (ag/make-memory :system "你是助理"))
(assert (= "你是助理" (ag/system-of m)))
(assert (= 1 (length (ag/messages m))))
(assert (= 0 (ag/turn-count m)))
(ag/set-system! m "改了")
(assert (= "改了" (ag/system-of m)) "set-system! 換掉第 0 則")
(assert (= 1 (length (ag/messages m))) "不會多一則")
(def m0 (ag/make-memory))
(assert (nil? (ag/system-of m0)) "沒給 system 就沒有")
(ag/set-system! m0 "補上")
(assert (= "system" (get-in (ag/messages m0) [0 :role])) "補上時插在最前面")

# ── 粗估 ────────────────────────────────────────────────────────────
(def e (ag/make-memory))
(ag/append! e (user "abcd"))                       # 4 字元
(ag/append! e (call "c1"))                         # arguments 20 字元
(ag/append! e @{:role "user" :content @[@{:type "text" :text "xy"} @{:type "image_url"}]})
(assert (= 26 (ag/estimate-chars e)) (string "字元：" (ag/estimate-chars e)))
(assert (= 7 (ag/estimate-tokens e)) "26 ÷ 4 無條件進位 = 7（是估的）")

# ── 截斷：以「輪」為單位，system 永遠留、tool_calls 與 tool 一起走 ────
(def t (ag/make-memory :system "S" :max-turns 2))
(ag/append! t (user "q1")) (ag/append! t (call "c1")) (ag/append! t (tool "c1")) (ag/append! t (asst "a1"))
(ag/append! t (user "q2")) (ag/append! t (asst "a2"))
(ag/append! t (user "q3")) (ag/append! t (call "c3")) (ag/append! t (tool "c3")) (ag/append! t (asst "a3"))
(assert (= 3 (ag/turn-count t)))
(assert (deep= @[1 5 7] (ag/turn-starts t)))
(assert (= 4 (ag/trim! t)) "丟掉整個第一輪＝4 則（user、tool_calls、tool、answer）")
(assert (deep= @["system" "user" "assistant" "user" "assistant" "tool" "assistant"] (roles t))
        (string/format "截斷後的形狀：%q" (roles t)))
(assert (= "q2" (get-in (ag/messages t) [1 :content])) "留下的是最近兩輪")
(assert (= 0 (ag/trim! t)) "已經在門檻內就什麼都不丟")
# 驗「配對沒拆散」：每個 tool 訊息前面一定找得到帶同 id 的 tool_calls
(each [i msg] (pairs (ag/messages t))
  (when (= "tool" (msg :role))
    (def prev (get (ag/messages t) (dec i)))
    (assert (= (msg :tool_call_id) (get-in prev [:tool_calls 0 :id])) "tool 前一則就是它的 tool_calls")))

# 依字元數截斷：把 max-chars 壓小，一次丟到剩最後一輪（min-turns 預設 1）
(def c (ag/make-memory :system "S" :max-chars 10))
(ag/append! c (user "aaaaaaaa")) (ag/append! c (asst "bbbbbbbb"))
(ag/append! c (user "cccccccc")) (ag/append! c (asst "dddddddd"))
(ag/append! c (user "eeeeeeeeeeeeeeeeeeee"))       # 這一輪自己就超過 10 字元
(assert (= 4 (ag/trim! c)))
(assert (deep= @["system" "user"] (roles c)) "最後一輪再大也留著（不然當前問題送不出去）")
(assert (= "S" (ag/system-of c)) "system 永遠在")

# min-turns 可調
(def k (ag/make-memory :max-chars 1 :min-turns 2))
(each i (range 3) (ag/append! k (user (string "q" i))) (ag/append! k (asst "a")))
(ag/trim! k)
(assert (= 2 (ag/turn-count k)) "至少留 2 輪")

# clear!
(ag/clear! t)
(assert (deep= @["system"] (roles t)))

# ── save! / load round-trip ─────────────────────────────────────────
(def path (string (or (os/getenv "TMPDIR") "/tmp") "/janet-agent-mem-" (os/getpid) ".json"))
(def s (ag/make-memory :system "你只講繁體中文" :max-turns 5 :max-chars 999 :min-turns 2))
(ag/append! s (user "台北天氣？")) (ag/append! s (call "c1")) (ag/append! s (tool "c1")) (ag/append! s (asst "答"))
(assert (= path (ag/save! s path)))
(def back (ag/load path))
(assert (deep= (ag/messages s) (ag/messages back)) "訊息（含 tool_calls 的巢狀結構、中文）原樣讀回")
(assert (= 5 (back :max-turns)))
(assert (= 999 (back :max-chars)))
(assert (= 2 (back :min-turns)))
(assert (string/find `"version":1` (string (slurp path))) "檔案裡有版本號")
(os/rm path)

# 壞掉的檔要講清楚
(assert (string/find "讀不到對話檔" (u/err-of |(ag/load "/沒這個/x.json"))))
(spit path "不是 json")
(assert (string/find "不是合法 JSON" (u/err-of |(ag/load path))))
(spit path `{"messages": [{"content": "沒 role"}]}`)
(assert (string/find "沒有 role" (u/err-of |(ag/load path))))
(spit path `[1,2]`)
(assert (string/find "不是一個 JSON 物件" (u/err-of |(ag/load path))))
(spit path `{}`)
(assert (string/find "缺 messages" (u/err-of |(ag/load path))))
(os/rm path)

(print "agent 記憶／截斷／save-load 測試通過 ✓")
