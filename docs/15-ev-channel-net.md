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

---

## 接下去

網路那半（`net` server／client）、常用 API 一覽與地雷清單搬到
**[15b · net 與速查](15b-net-與速查.md)**。
