#!/usr/bin/env janet
# 優雅關閉：Ctrl-C 或 SIGTERM 進來時，先把該收的收乾淨再退出。
# 跑法：
#   janet snippets/graceful-shutdown.janet        ← 跑 8 秒後自然結束
#   janet snippets/graceful-shutdown.janet &      ← 然後 kill -TERM <pid> 看收尾
#   （直接在終端機按 Ctrl-C 也一樣）
#
# 為什麼要這支：長時間跑的東西（伺服器、watcher、批次工作）被 kill 掉時，
# 沒收尾就會留下：沒關的連線、寫到一半的檔案、沒刪的暫存檔、沒 flush 的日誌。
# 相關：docs/11（signal）、docs/20b（defer / with）、snippets/parallel-batch。

# ── 1. 收尾工作清單 ──────────────────────────────────────────
# 用一張清單而不是一個大函式：之後隨時可以往裡面加，而且順序看得見（後進先出）。
(def 收尾清單 @[])

(defn 註冊收尾
  "註冊一件離開前要做的事。回傳它自己，方便串接。"
  [名 f]
  (array/push 收尾清單 [名 f]))

(var 收尾過? false)

(defn 收尾
  ``跑完所有收尾工作。
  ⚠ 三個一定要做對的地方：
    ① **只能跑一次**——Ctrl-C 連按兩下、或 SIGINT 之後又來 SIGTERM，
       沒擋的話會關兩次連線、刪兩次檔。
    ② **後進先出**——先開的後關（跟 defer 巢狀的順序一樣，見 docs/20b）。
    ③ **每一件都要包 protect**——其中一件炸了不能害後面的做不完。``
  [why]
  (if 收尾過?
    (eprint "（已經在收尾了，忽略 " why "）")
    (do
      (set 收尾過? true)
      (eprintf "收到 %s，收尾中…" why)
      (each [名 f] (reverse 收尾清單)
        (def [ok e] (protect (f)))
        (eprintf "  %-22s %s" 名 (if ok "✓" (string "✘ " e))))
      (eprint "收尾完成"))))

# ── 2. 掛上信號 ──────────────────────────────────────────────
# 合法的 signal keyword：:int :term :hup :kill :usr1 :usr2 :quit
# ⚠ :kill 攔不到（SIGKILL 本來就不可攔），所以「一定會執行的收尾」不存在——
#   真正重要的狀態要寫進檔案，別只留在記憶體裡。
(defn 掛信號 []
  (each [sig 名] [[:int "SIGINT（Ctrl-C）"] [:term "SIGTERM"] [:hup "SIGHUP"]]
    (os/sigaction sig (fn [] (收尾 名) (os/exit 0)))))

# ── 3. 示範 ──────────────────────────────────────────────────
(defn main [&]
  (def 目錄 (os/getenv "TMPDIR" "/tmp"))
  (def 暫存 (string 目錄 "/janet-shutdown-demo.tmp"))
  (def 進度檔 (string 目錄 "/janet-shutdown-progress.txt"))
  (spit 暫存 "工作中…")

  # ⚠ 註冊順序很重要，因為收尾是 **LIFO**——最後註冊的最先跑。
  #   我第一版把「刪暫存檔」註冊在「寫回進度」後面，結果刪完又被寫回來，
  #   檔案根本沒清掉。照「取得資源的順序」註冊就不會錯。
  (註冊收尾 "刪暫存檔"     (fn [] (os/rm 暫存)))          # 最先註冊 → 最後跑
  (註冊收尾 "寫回進度"     (fn [] (spit 進度檔 "已安全收尾")))
  (註冊收尾 "flush 日誌"   (fn [] (:flush stdout) (:flush stderr)))
  (註冊收尾 "示範失敗的一件" (fn [] (error "這件收尾自己炸了")))  # 最後註冊 → 最先跑

  (掛信號)

  (printf "PID=%d，跑 8 秒後自然結束。" (os/getpid))
  (print "想看收尾：另開一個終端機下 kill -TERM " (os/getpid) "，或直接按 Ctrl-C。")
  (print "註冊了 4 件收尾工作，其中一件會故意失敗——看它不會擋住其他三件。\n")

  # 模擬「一直在做事」
  (for i 1 9
    (printf "  工作中… %d/8" i)
    (:flush stdout)
    (ev/sleep 1))

  # 自然結束也要收尾（不是只有被 kill 才收）
  (收尾 "正常結束")
  (os/exit 0))
