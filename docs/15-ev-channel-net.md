# 15 · ev 的另外半邊：channel、真執行緒、網路

[09-fiber.md](09-fiber.md) 講了 fiber 和 `ev/spawn`／`ev/sleep`。這篇補上剩下的：
**channel**（fiber 之間傳東西）、**真 OS 執行緒**、**取消與逾時**、**內建 net**。

## 三種「同時做事」的差別

| 東西 | 幾條 OS 執行緒 | 什麼時候用 |
|------|--------------|-----------|
| `ev/spawn` / `ev/go` | 1（協作式） | IO 等待、並行請求。**九成場合用這個** |
| `ev/thread` / `ev/do-thread` | 真的多條 | CPU 密集工作，要吃滿多核 |
| `os/spawn` | 另一個行程 | 跑別的程式（見 [11](11-pipeline-signal.md)） |

`ev/spawn` 是**單執行緒協作式**：只有在 `ev/sleep`、channel 操作、網路讀寫這些點才會切換。
純 CPU 迴圈**不會**被切走——這是特性不是 bug，代表你不用煩惱 race condition。

## channel

```janet
(def ch (ev/chan 10))         # 容量 10 的緩衝 channel；(ev/chan) 是無緩衝
(ev/give ch :值)              # 送（滿了會擋）
(ev/take ch)                  # 取（空了會擋）
(ev/count ch) (ev/capacity ch) (ev/full ch)
(ev/chan-close ch)
```

### ★ 最大的坑：`chan-close` 會讓緩衝區裡的東西拿不到

```janet
(ev/give ch :a) (ev/give ch :b)
(ev/count ch)          ;=> 2      東西還在
(ev/chan-close ch)
(ev/take ch)           ;=> nil    ★ 但一個都讀不到了
```

所以「生產者做完就 `chan-close`、消費者 `loop … :iterate (ev/take ch)` 讀到 nil 為止」
這個從 Go 搬過來的標準寫法，在 Janet 會**安靜地掉資料**。要嘛別 close（讓消費者自己數
夠了就停），要嘛送一個結束哨兵值：

```janet
(ev/spawn (for i 0 3 (ev/give ch i)) (ev/give ch :done))
(loop [v :iterate (ev/take ch) :until (= v :done)] (pp v))
```

### select：等多個 channel，誰先來聽誰的

```janet
(ev/select a b)          ;=> (:take <channel> 值) 或 (:close <channel>)
(ev/select a [b 值])     # tuple 形式 = 「等著把值送進 b」
```

回傳的第二個元素是**哪一個 channel**，拿它跟你的 channel 比對就知道發生了什麼。

### gather：等一堆工作全部做完

```janet
(ev/gather (do (ev/sleep 0.01) :a)
           (do (ev/sleep 0.02) :b))    ;=> @[:a :b]   ← 順序照寫的順序，不照完成順序
```

## 真 OS 執行緒

```janet
(ev/do-thread (print "我在另一條執行緒"))   # 擋著等它做完，回傳 nil

(def tc (ev/thread-chan 10))                # ★ 跨執行緒要用 thread-chan
(ev/thread (fn [c] (ev/give c (+ 1 2))) tc :n)   # :n = 不等它，立刻返回
(ev/take tc)                                ;=> 3
```

兩個要點：

- **不加 `:n` 會死鎖**：`ev/thread` 預設會 suspend 當前 fiber 等執行緒結束，
  但執行緒又在等你收它的 channel → 互相等。要拿結果就加 `:n`。
- **跨執行緒的 channel 要 `ev/thread-chan`**，普通 `ev/chan` 只在同一個執行緒內有效。
- 執行緒之間**不共享可變狀態**，傳過去的值會被 marshal 複製一份。所以不會有 data race，
  但也不能靠共用 table 溝通。

## 取消與逾時

```janet
(ev/with-deadline 0.05 (ev/sleep 10))
;=> 丟出 "deadline expired"，用 (protect …) 或 (try …) 接

(def task (ev/go (fn [] (forever (ev/sleep 0.05)))))
(ev/cancel task :理由)      # 對方會在「下一次 ev 操作」收到這個當例外
```

> **取消是合作式的**：`ev/cancel` 只有在對方進入 `ev/sleep` / channel / 網路等待時才生效。
> 純 CPU 迴圈砍不掉——要能中斷就自己在迴圈裡檢查旗標。完整的
> 「Go context 風格」封裝見 [`snippets/fiber-context/`](../snippets/fiber-context/)。

還有一個實務陷阱：**排在 ev 迴圈上的計時器會讓程式不肯結束**。
`(ev/go (fn [] (ev/sleep 99) …))` 一掛上去，主程式做完了也得等那 99 秒。所以逾時用完
記得把計時器 `ev/cancel` 掉——就是 Go 那句 `defer cancel()` 的理由。

## 內建 net：五行一台 server

```janet
(def s (net/listen "127.0.0.1" 8931))
(ev/spawn
  (net/accept-loop s
    (fn [conn]
      (defer (:close conn)
        (def req (:read conn 1024))
        (:write conn (string "你送了 " (length req) " bytes\n"))))))
```

client：

```janet
(with [c (net/connect "127.0.0.1" 8931)]
  (:write c "hello")
  (string (:read c 100)))
```

`net/accept-loop` 每來一條連線就開一個 fiber 跑你的 handler，所以**天生併發**、
而且寫起來像同步程式碼，沒有 callback 地獄也沒有 async 染色。

其他：`net/server`（listen + accept-loop 合一）、`net/accept`、`net/write`、`net/flush`、
UDP 用 `net/listen`／`net/connect` 加 `:datagram`。

## 常用 API 一覽

| 用途 | 函式 |
|------|------|
| 起 fiber | `ev/spawn`（值）、`ev/go`（回傳 task fiber，可取消） |
| 睡 | `ev/sleep`（秒，可小數） |
| channel | `ev/chan` `ev/thread-chan` `ev/give` `ev/take` `ev/select` `ev/rselect` `ev/chan-close` `ev/count` `ev/capacity` `ev/full` |
| 等一批 | `ev/gather` `ev/go-gather` |
| 執行緒 | `ev/thread` `ev/do-thread` `ev/spawn-thread` |
| 逾時 / 取消 | `ev/with-deadline` `ev/deadline` `ev/cancel` |
| 鎖（只在多執行緒時才需要） | `ev/lock` `ev/with-lock` `ev/rwlock` `ev/with-rlock` `ev/with-wlock` |
| 串流 IO | `ev/read` `ev/write` `ev/chunk` `ev/to-file` |

## 地雷

| 症狀 | 原因 / 正解 |
|------|------------|
| close 之後資料不見 | `ev/chan-close` 會丟掉緩衝內容。用哨兵值代替 close |
| `ev/thread` 卡死 | 沒加 `:n`，主 fiber 等執行緒、執行緒等你收 channel |
| 跨執行緒 channel 沒反應 | 要用 `ev/thread-chan`，不是 `ev/chan` |
| 程式做完了卻不結束 | 還有 `ev/sleep` 的計時 fiber 掛在迴圈上，把它 `ev/cancel` 掉 |
| `ev/cancel` 砍不掉對方 | 對方在跑純 CPU 迴圈。合作式取消，自己要留檢查點 |
| 執行緒改了共用 table，主線看不到 | 執行緒間的值是 marshal 複製，不共享。用 channel 傳回來 |

---

可跑範例：[`snippets/fiber-context/`](../snippets/fiber-context/)（Go 風格 context）、
[`examples/fibers.janet`](../examples/fibers.janet)（基礎 fiber）。

下一步：[16-marshal-與自省.md](16-marshal-與自省.md)。
