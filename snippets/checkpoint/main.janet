#!/usr/bin/env janet
# 長工作做到一半存檔（checkpoint），下次啟動從斷點續跑——用 image 存「暫停中的 fiber」。
# 跑法：
#   janet snippets/checkpoint/main.janet 4     # 做 4 步就「當掉」（模擬中斷）
#   janet snippets/checkpoint/main.janet       # 再跑：從第 5 步接下去，做完刪 checkpoint
#   janet snippets/checkpoint/main.janet reset # 丟掉 checkpoint 重頭來
#
# 重點：
#   * 存的不是「進度數字」而是**暫停中的 fiber 本身**，連它閉包裡的 acc、done 一起進 image；
#     所以工作邏輯不用為了「可續跑」改寫成狀態機。
#   * fiber 只能在 yield 的地方斷；每步之間 yield 一次，checkpoint 的粒度就是一步。
#   * ⚠ image 綁 Janet 版本、也存不了 file／socket：資源在每一步裡開、用完關，不要橫跨 yield。
#   * ⚠ 讀不回來（版本換了、檔案壞了）就當沒有 checkpoint，重頭來；別讓壞檔卡死程式。
#   * 寫檔先寫 .tmp 再 os/rename，中途斷電不會留下半個 checkpoint。
#     ⚠ Windows 的 os/rename 遇到目標已存在會丟 "File exists"，POSIX 會直接覆寫；所以先 os/rm。

(def ckpt "checkpoint.jimage")
(def total 10)

(defn make-job []
  (fiber/new
    (fn []
      (var acc 0)
      (def done @[])
      (for i 1 (inc total)
        (os/sleep 0.2)                        # 假裝每步很貴；真資源在這裡開、這裡關
        (+= acc i)
        (array/push done i)
        (yield {:step i :acc acc :done (length done)}))
      {:finished true :acc acc})))

(defn save [job]
  (def tmp (string ckpt ".tmp"))
  (spit tmp (make-image @{'job @{:value job}}))
  (when (os/stat ckpt) (os/rm ckpt))   # ⚠ Windows 的 os/rename 不覆寫既有檔（POSIX 會）；這一行讓它兩邊都能跑
  (os/rename tmp ckpt))

(defn load-job []
  (when (os/stat ckpt)
    (match (protect (get-in (load-image (slurp ckpt)) ['job :value]))
      [true (job (fiber? job))] (do (print "從 " ckpt " 續跑") job)
      [true _] (do (eprint "checkpoint 裡沒有 fiber，重頭來") nil)
      [false err] (do (eprint "checkpoint 讀不回來（" err "），重頭來") nil))))

(defn main [_ &opt arg]
  (when (= arg "reset") (when (os/stat ckpt) (os/rm ckpt)) (print "已清掉") (os/exit 0))
  (def crash-at (if arg (scan-number arg) math/inf))
  (def job (or (load-job) (make-job)))
  (var steps-this-run 0)
  (while (index-of (fiber/status job) [:new :pending])   # ⚠ 新 fiber 是 :new 不是 :pending
    (def progress (resume job))
    (when (get progress :finished)
      (printf "完成，acc=%d" (progress :acc))
      (os/rm ckpt)
      (break))
    (save job)                                  # 每步存一次；貴的話改成每 N 步
    (printf "step %d/%d acc=%d（已存 checkpoint）" (progress :step) total (progress :acc))
    (when (>= (++ steps-this-run) crash-at)
      (print "…假裝當掉，下次跑會接著做")
      (os/exit 1))))
