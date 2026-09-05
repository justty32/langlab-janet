# aos —— 把 aos 那套「資料夾當程式、檔案當指令」的機制綁進 Janet（門面）。
#
# 兩句話：
#   一塊地（有 `.aos/` 的資料夾）就是一支程式 → (aos/call 地 args) 呼叫它、(aos/fn 地) 包成函式。
#   一個檔案（可執行檔或腳本）就是一筆指令   → (aos/exec-file 路徑 & argv)。
#
# ── 拆檔 ────────────────────────────────────────────────────────────
#   fsx.janet     檔案協定底層：32 hex id、ISO 時間戳、原子寫、json、O_EXCL 鎖
#   land.janet    認一塊地、算 .aos/ 底下的路徑、建地、lib 自己的暫存區（＝合成的呼叫方）
#   proc.janet    子行程呼叫 `python3 <aos>/proto/aos.py …`（exec／run／daemon）
#   deliver.janet 投遞協定：<id>.json.temp → rename
#   call.janet    同步呼叫、呼叫記錄、結果落點、三態、(aos/fn) 糖
#   inst.janet    檔案當指令：投一筆 kind:"inst"、走一格、讀執行結果檔
#   async.janet   脫節呼叫：登記表那筆、daemon 檢查、handle／status／await
#
# ★ 檔案協定（呼叫記錄、投遞、結果、狀態檔、登記表）**Janet 自己寫**；
#   只有「推機器動一下」的 exec／run／daemon 才 shell 出去給原型。
#
# ⚠ 原型的位置預設寫死在 proc.janet；換 repo 就設環境變數 `AOS_PROTO` 指到那支 aos.py。
# ⚠ 測試與範例一律把 `AOS_HOME` 指到暫存目錄，不要用真正的 `~`。

(import ./fsx     :prefix "" :export true)
(import ./land    :prefix "" :export true)
(import ./proc    :prefix "" :export true)
(import ./deliver :prefix "" :export true)
(import ./call    :prefix "" :export true)
(import ./inst    :prefix "" :export true)
(import ./async   :prefix "" :export true)

# ── 兩個別名，讓呼叫端讀起來像使用者說的那樣 ────────────────────────
# ⚠ `fn` 是特殊形式：本檔之後就不能再寫 (fn …) 或 defn 之外的裸 fn 了，所以擺在最後。
#   呼叫端寫的是**限定符號** (aos/fn …)，特殊形式不會攔截，安全。
(def await await-result)
(def fn land-fn)
