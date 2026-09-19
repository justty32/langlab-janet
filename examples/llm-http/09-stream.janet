# llm-http 範例 ⑨ —— 串流（SSE）：邊收邊印，最後還是拿到一份完整回應。
#
# 非串流的 ask 要等模型講完才回；串流是送 stream:true，伺服器一小塊一小塊推回來，
# 每塊叫一次 :on-delta。收完後 chat-stream 把片段合成跟 chat **同形狀**的回應，
# 所以 reply-text／reply-finish-reason／reply-usage 照用。
#
# 傳輸自動選：http:// 走 net/connect 手寫的 HTTP/1.1（spork 的 http/request 只讀第一個事件），
# https:// 走 curl -N。細節見 modules/llm-http/doc/streaming.md。
#
# ── 前置條件 ────────────────────────────────────────────────────────
#   跟 01 一樣要有一台 OpenAI 相容伺服器（litellm proxy 或 LM Studio）。
#   沒起來會印「連不上」提示，不噴 stacktrace。
#
# ── 跑法 ────────────────────────────────────────────────────────────
#   janet examples/llm-http/09-stream.janet [endpoint 名字] [問題]

(import ../../modules/llm-http/init :as llm)

(def hint "\n提示：後端沒起來。先起 litellm proxy（見 01-minimal.janet 檔頭），位址用 127.0.0.1。")

(defn attempt [label f]
  (def [ok v] (protect (f)))
  (unless ok
    (flush)
    (eprintf "✗ %s 失敗：\n   %s" label v)
    (when (string/find "連不上" (string v)) (eprint hint)))
  (if ok v))

(defn main [& args]
  (def name   (get args 1 "local"))
  (def prompt (get args 2 "用三句話介紹 Janet 這個語言。"))
  (def cfg (llm/endpoint name))
  (unless cfg
    (eprintf "沒有這個 endpoint：%s（可用：%s）" name (string/join (llm/endpoint-names) "、"))
    (os/exit 1))
  (printf "endpoint = %s（%s）\n問 = %s\n" name (cfg :url) prompt)

  # ── ① ask-stream：最省事，預設就是「印到 stdout ＋ flush」，收完補換行 ──
  (print "── ① ask-stream ──")
  (when-let [text (attempt "ask-stream" |(llm/ask-stream cfg prompt))]
    (printf "（完整答案共 %d bytes）" (length text)))

  # ── ② chat-stream：自己接 :on-delta，拿到完整回應看 finish_reason／usage ──
  (print "\n── ② chat-stream ＋ 自訂 on-delta ──")
  (var pieces 0)
  (def res (attempt "chat-stream"
                    |(llm/chat-stream cfg @[@{:role "user" :content prompt}]
                                      :max-tokens 200
                                      :on-delta (fn [t] (++ pieces) (prin t) (flush)))))
  (when res
    (print)
    (printf "收到 %d 段 delta、%d 個 SSE 事件" pieces (res :chunks))
    (printf "finish_reason = %q" (llm/reply-finish-reason res))
    (printf "usage = %q" (llm/reply-usage res))
    (when (llm/truncated? res)
      (print "⚠ 被 max_tokens 截斷了——串流時 HTTP 200 一樣不代表講完，finish_reason 還是要看"))))
