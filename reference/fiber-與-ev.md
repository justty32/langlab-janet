# fiber 與 ev ・ 全部 50 個

[← reference 索引](README.md)

`fiber/*` 10 ＋ `ev/*` 40。對應教學：[09 fiber](../docs/09-fiber.md)、
[15 ev channel／執行緒](../docs/15-ev-channel-net.md)、[15b net](../docs/15b-net-與速查.md)、
[30 spork 並行](../docs/30-spork-並行與服務.md)。

> 對著 `root-env` 逐一核過，50 個一個不漏。

## 兩層要先分清楚

| | 是什麼 | 真的平行嗎 |
|---|--------|-----------|
| **fiber** | 協程——手動 `resume`／`yield`，單執行緒 | ✘ |
| **ev 的 task** | 掛在事件迴圈上的 fiber，IO 時自動讓出 | ✘（但 IO 不會互相擋）|
| **ev/thread** | **真的 OS 執行緒**，各自有獨立的 VM | ✓ |

⚠ 前兩者共用記憶體、可以直接傳任何值；**執行緒之間只能傳 marshal 得動的東西**
（見 [16](../docs/16-marshal-與自省.md)）。CPU 密集的工作才值得開執行緒。

## `fiber/*`（10 個）

| 函式 | 簽名 | 說明 |
|------|------|------|
| `fiber/new` | `(fiber/new func &opt sigmask env)` | 造一個；`sigmask` 決定攔哪些信號（`:e` 攔 error、`:y` 攔 yield…）|
| `fiber/status` | `(fiber/status fib)` | `:new` `:pending` `:alive` `:dead` `:error` `:user0`… |
| `fiber/current` | `(fiber/current)` | 現在跑在哪個 fiber 裡 |
| `fiber/root` | `(fiber/root)` | 最外層那個（＝ ev 的 task）|
| `fiber/can-resume?` | `(fiber/can-resume? fiber)` | 還叫得動嗎 |
| `fiber/last-value` | `(fiber/last-value fiber)` | 上次 yield／回傳的值 |
| `fiber/getenv` / `fiber/setenv` | `(… fiber [table])` | 它的環境表——**切換 env 求值靠這個**（[12b](../docs/12b-切換-env.md)）|
| `fiber/maxstack` / `fiber/setmaxstack` | `(… fib [n])` | 堆疊上限 |

⚠ `resume`／`yield`／`cancel`／`propagate` **不在 `fiber/` 底下**，是頂層函式。

## `ev/*`（40 個）

### 起一個任務

| 函式 | 簽名 | 說明 |
|------|------|------|
| `ev/spawn` | `(ev/spawn & body)` | 把 body 丟成一個 task，**立刻回傳** |
| `ev/go` | `(ev/go fiber-or-fun &opt value supervisor)` | 同上但吃現成的 fiber，可指定監督者 |
| `ev/call` | `(ev/call f & args)` | 用一個新 task 跑 `(f ;args)` |
| `ev/do-thread` | `(ev/do-thread & body)` | 在**新執行緒**跑 body，等它回來 |
| `ev/spawn-thread` | `(ev/spawn-thread & body)` | 同上但不等 |
| `ev/thread` | `(ev/thread main &opt value flags supervisor)` | 完整版執行緒 |
| `ev/all-tasks` | `(ev/all-tasks)` | 現在有哪些 task |

### 等待與取消

| 函式 | 簽名 | 說明 |
|------|------|------|
| `ev/sleep` | `(ev/sleep sec)` | ⚠ 只讓出**這個 task**；擋整個行程的是 `os/sleep` |
| `ev/gather` | `(ev/gather & bodies)` | 全部跑完才回，回結果陣列 |
| `ev/go-gather` | `(ev/go-gather thunks)` | 同上但吃一個 thunk 陣列 |
| `ev/deadline` | `(ev/deadline sec &opt tocancel tocheck intr?)` | 排一個逾時取消；`tocancel` 必須是 **root fiber** |
| `ev/with-deadline` | `(ev/with-deadline sec & body)` | ★ 常用版：超時丟 **`"deadline expired"`**，`try` 接得到 |
| `ev/cancel` | `(ev/cancel fiber err)` | 取消一個 task |

### channel

| 函式 | 簽名 | 說明 |
|------|------|------|
| `ev/chan` | `(ev/chan &opt capacity)` | 容量省略＝**無緩衝**（give 會等到有人 take）|
| `ev/give` | `(ev/give channel value)` | 放進去 |
| `ev/take` | `(ev/take channel)` | 拿出來 |
| `ev/chan-close` | `(ev/chan-close chan)` | 關掉 |
| `ev/count` / `ev/capacity` / `ev/full` | `(… channel)` | 現有幾個／容量／滿了沒 |
| `ev/select` | `(ev/select & clauses)` | 等多個 channel，誰先好就走誰 |
| `ev/rselect` | `(ev/rselect & clauses)` | 同上但**隨機**挑順序（避免總是餓死同一個）|
| `ev/thread-chan` | `(ev/thread-chan &opt limit)` | **跨執行緒**的 channel |
| `ev/give-supervisor` | `(ev/give-supervisor tag & payload)` | 往監督者的 channel 送訊息 |

### 鎖

| 函式 | 說明 |
|------|------|
| `ev/lock` / `ev/acquire-lock` / `ev/release-lock` | 互斥鎖 |
| `ev/rwlock` / `ev/acquire-rlock` / `ev/acquire-wlock` / `ev/release-rlock` / `ev/release-wlock` | 讀寫鎖 |
| `ev/with-lock` / `ev/with-rlock` / `ev/with-wlock` | `(… lock & body)` ★ **一律用這三個**——保證解鎖 |

⚠ 單執行緒的 task 之間**不需要鎖**（不會被搶佔）；鎖是給 `ev/thread` 用的。

### stream（非同步 IO）

| 函式 | 簽名 | 說明 |
|------|------|------|
| `ev/read` | `(ev/read stream n &opt buffer timeout)` | 讀最多 n 個 byte |
| `ev/chunk` | `(ev/chunk stream n &opt buffer timeout)` | 讀**剛好** n 個（不足就等）|
| `ev/write` | `(ev/write stream data &opt timeout)` | 寫 |
| `ev/close` | `(ev/close stream)` | 關 |
| `ev/to-file` | `(ev/to-file)` | stream → 一般 file handle |

net 那組（`net/server` `net/connect`…）在 [15b](../docs/15b-net-與速查.md)。

## 常用組合

```janet
(ev/with-deadline 5 (做事))                 # 逾時就丟 "deadline expired"
(ev/gather (工作1) (工作2))                  # 兩個一起跑，都完成才回
(ev/with-lock 鎖 (改共用狀態))               # 保證解鎖
(def c (ev/chan 10)) (ev/spawn (ev/give c 1))
```

限流的並行 map 不在內建裡——`spork/ev-utils` 的 `(pmap f 資料 n-workers)`
**限流而且結果保序**，但 ⚠ 一個失敗會整批丟出
（繞法見 [`snippets/parallel-batch.janet`](../snippets/parallel-batch.janet)）。
