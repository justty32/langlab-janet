# 15b · net 與速查

[← 15 ev：channel、真執行緒、網路](15-ev-channel-net.md)

`net` 是內建的（不是 spork），底層就是 ev，所以每條連線天生併發、不用自己開執行緒。

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
