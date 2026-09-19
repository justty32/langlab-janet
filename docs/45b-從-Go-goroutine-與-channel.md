# 45b · 從 Go 過來：goroutine、channel、select、context、真執行緒

[← 45 入口](45-從-Go-過來.md)

先講最重要的一句：**Janet 的 `ev` 是單執行緒的事件迴圈，不是 goroutine 排程器。**
`ev/go` 起的東西只在 `ev/sleep`、channel、網路讀寫這些點才會切換；純 CPU 迴圈不會被搶走。
真的要多核用 `ev/thread`（下面）。完整說明在 [15](15-ev-channel-net.md)，這篇只做對照。

| Go | Janet | 備註 |
|----|-------|------|
| `go f()` | `(ev/go f)`／`(ev/spawn body…)` | 回 fiber |
| `make(chan T, n)` | `(ev/chan n)`；`(ev/chan)` 是無緩衝 | |
| `ch <- v`／`<-ch` | `(ev/give ch v)`／`(ev/take ch)` | 滿了／空了會擋，一樣 |
| `close(ch)` | `(ev/chan-close ch)` | ⚠ 見下，語意不同 |
| `select { … }` | `(ev/select a b)` | 回 `(:take ch 值)`／`(:close ch)` |
| `time.After` 當逾時 | `(ev/with-deadline 秒 body)` | 逾時丟 `"deadline expired"` |
| `sync.WaitGroup` | `(ev/gather 工作…)` | 全部做完回 array，順序照寫的順序 |
| `context.WithCancel` | `(ev/cancel fiber 理由)` | 合作式，[`snippets/fiber-context/`](../snippets/fiber-context/) 做成 Go 的樣子 |
| `sync.Mutex` | 通常**不需要**；有 `ev/lock` | 單執行緒沒有 data race |
| 真的多核 | `(ev/thread f nil :n)` ＋ `ev/thread-chan` | 值會 marshal 複製，不共享記憶體 |

## goroutine → ev/go：單執行緒，要有讓出點才交錯

```janet
(def log @[])
(ev/go (fn [] (for i 0 3 (array/push log [:a i]))))
(ev/go (fn [] (for i 0 3 (array/push log [:b i]))))
(ev/sleep 0)
log   # => @[(:a 0) (:a 1) (:a 2) (:b 0) (:b 1) (:b 2)]   沒有讓出點，a 跑完才輪到 b
```

同一段在 for 裡加 `(ev/sleep 0)` 就變 `a0 b0 a1 b1 a2 b2`（[15](15-ev-channel-net.md) 有實測）。
這是特性：不會有 race，所以不用 mutex；代價是 CPU 密集的工作要自己切成小段或丟到 `ev/thread`。

⚠ 兩件跟 Go 相反的事，都實測過：

- **goroutine 裡 panic 會殺掉整個程式；`ev/go` 裡 `error` 不會**。它把錯誤印到 stderr、
  該 fiber 狀態變 `:error`，主程式繼續。
- **Go 的 main 一結束 goroutine 全死；Janet 的主檔案跑完後，還排在 ev 迴圈上的工作會繼續跑完**。
  `(ev/go (fn [] (print "後")))` 放在最後一行，程式照樣印出來才退出。掛了 `(ev/sleep 99)` 的工作會讓程式等 99 秒。

## channel：close ＋ range 的慣用法要改寫

⚠ Go 最常見的「生產者 `close(ch)`、消費者 `for v := range ch`」搬過來會**安靜地掉資料**：
`ev/chan-close` 之後緩衝區裡剩的東西一個都讀不到（[15](15-ev-channel-net.md) 的 ★）。兩種改法：

```janet
# ① 送哨兵值，不 close
(def ch (ev/chan 2))
(ev/go (fn [] (for i 0 3 (ev/give ch i)) (ev/give ch :done)))
(def got @[])
(while (not= :done (def v (ev/take ch))) (array/push got v))
got   # => @[0 1 2]
# ② 用無緩衝 channel：give 會等到有人 take，所以 close 時已經全部送出
(def ch2 (ev/chan))
(ev/go (fn [] (for i 0 3 (ev/give ch2 i)) (ev/chan-close ch2)))
(def got2 @[])
(while (def v (ev/take ch2)) (array/push got2 v))
got2  # => @[0 1 2]
```

`(ev/take 已關閉的)` 回 `nil`，跟 Go 的零值＋`ok=false` 對應。

## select 與逾時

```janet
(def a (ev/chan)) (def b (ev/chan))
(ev/go (fn [] (ev/sleep 0.02) (ev/give a :slow)))
(ev/go (fn [] (ev/give b :fast)))
(ev/select a b)                  # => (:take <core/channel 0x…> :fast)   第二格是哪個 channel
(def c (ev/chan))
(try (ev/with-deadline 0.01 (ev/take c)) ([e] e))   # => "deadline expired"
```

Go 的 `case <-time.After(d)` 沒有對應的 case 形式；把整段 `select` 包進 `ev/with-deadline` 就是那個意思。
`(ev/select a [b 值])` 的 tuple 形式是「等著送進 b」，對到 `case b <- v`。

## WaitGroup → gather；context → cancel

```janet
(ev/gather (do (ev/sleep 0.002) 1) (do (ev/sleep 0.001) 2))   # => @[1 2]   照寫的順序，不照完成順序
(def worker (ev/go (fn [] (try (forever (ev/sleep 0.001)) ([e] [:got e])))))
(ev/sleep 0.005)   # 讓 worker 先跑進 try，否則 cancel 打在它開始前
(ev/cancel worker "cancelled")
(ev/sleep 0.01)
(fiber/status worker)   # => :dead
```

`ev/cancel` 讓對方**在下一次 ev 操作時**收到那個值當例外，所以 CPU 迴圈砍不掉，要自己檢查旗標——
就是 Go 的 `ctx.Done()` 那個 `select`。值傳遞（`ctx.Value`）、逾時、階層傳播全做在
[`snippets/fiber-context/`](../snippets/fiber-context/)。

## 真執行緒：ev/thread

```janet
(def tc (ev/thread-chan 1))
(ev/thread (fn [chan] (ev/give chan [:from-thread (os/cpu-count)])) tc :n)
(ev/take tc)   # => (:from-thread 8)   數字看你的機器
```

三件事：**要加 `:n`**（不加會等執行緒結束，而執行緒又在等你收 channel，互相等）；
**跨執行緒的 channel 要 `ev/thread-chan`**；`ev/thread` 本身**回傳 `nil`**，結果只能從 channel 拿
（docstring 明講 "Otherwise, returns nil"）。傳過去的值會被 marshal 複製，所以沒有 data race，也沒有共用 table。
`ev/do-thread` 是同步版：擋著等它做完。

## package／go build → jpm

`go.mod` 對到 `project.janet`，`go get` 對到 `jpm deps`，`go build` 產單一執行檔對到 `jpm build`
配 `declare-executable`（[05](05-jpm-與專案.md)）。`go test` 是 `jpm test`，跑 `test/` 底下每支檔（[23](23-測試怎麼寫.md)）。
`package` 就是一個 `.janet` 檔，`import` 的規則在 [05e](05e-import-與模組路徑.md)。

## 可跑範例

```sh
janet examples/compare-go.janet
```

下一步：[15 ev、channel、net](15-ev-channel-net.md) 把 channel 那套走完，或 [09 fiber](09-fiber.md) 看 `ev/go` 底下是什麼。
