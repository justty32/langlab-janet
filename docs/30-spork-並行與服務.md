# 30 · spork 並行與服務

[09 Fiber](09-fiber.md) 與 [15 ev](15-ev-channel-net.md) 教了 Janet 內建的並行機制。
這篇講 spork 疊在上面的**實用層**——最重要的是第一節，其餘知道有就好。

## 一、pmap：把一堆工作同時做完

這是整個 spork 並行系統裡**你最常用到的一個函式**。

```janet
(import spork/ev-utils)

(ev-utils/pmap (fn [x] (* x x)) [1 2 3 4 5])   # => @[1 4 9 16 25]
```

看起來跟 `map` 一樣，差別是它**同時跑**。實測五個各睡 0.1 秒的工作：

```janet
(def t0 (os/clock :monotonic))
(ev-utils/pmap (fn [_] (ev/sleep 0.1)) (range 5))
(- (os/clock :monotonic) t0)     # => 0.0998 秒（循序做要 0.5 秒）
```

### ⚠ 它並行，但**結果保證照原順序**

這點很容易誤會，所以特別實測——讓第一個元素睡最久：

```janet
(ev-utils/pmap (fn [x] (ev/sleep (/ (- 5 x) 100)) x) [1 2 3 4 5])
# => @[1 2 3 4 5]     ← 不是完成順序
```

`1` 最晚做完，但它還是排在結果的第一個。**你不必自己重排。**

### 控制同時跑幾個

```janet
(ev-utils/pmap-limited f 資料 2)   # 最多同時 2 個
(ev-utils/pmap-full f 資料)         # 全部一起上，不設限
(ev-utils/pmap f 資料 4)            # 第三參也能給 worker 數
```

⚠ **要限制數量的場合**：打外部 API（會被 rate limit）、開檔案（有 fd 上限）、
吃記憶體的工作。無腦 `pmap-full` 丟一萬筆進去會出事。

> **重要前提**：`pmap` 靠的是 **fiber**，不是 OS 執行緒——所以它只在工作會
> **等待 IO**（網路、檔案、`ev/sleep`）時才有意義。純算術的工作用 `pmap` **不會變快**，
> 因為它們從頭到尾佔著同一顆 CPU。要真的用多核心請看 [15 ev 的真執行緒](15-ev-channel-net.md)。

## 二、nursery：讓背景工作不會偷偷跑掉

「**nursery（托兒所）**」是結構化並行的概念：**開出去的工作不准活得比它的 nursery 久**。

```janet
(def n (ev-utils/nursery))
(ev-utils/go-nursery n (fn [] (ev/sleep 0.01) (print "工作跑完")))
(ev-utils/join-nursery n)      # 等到裡面的工作全部結束才往下走
(print "join 回來了")
```

好處是**不會有孤兒工作**：離開這段程式碼時，你確定沒有東西還在背景亂跑。
沒有 nursery 的話，`ev/go` 出去的 fiber 可能在你以為結束後還活著。

## 三、generators：真正的惰性序列

[25 序列工具](25-序列工具.md) 說過內建的 `map`／`filter` 全是 eager。
`spork/generators` 提供一整套**同名但惰性**的版本：

```janet
(import spork/generators :as gen)

(gen/to-array (gen/take 3 (gen/range 0 1000000)))   # => @[0 1 2]
```

一百萬的 range **只真的算了三個**。實測計數確認：

```janet
(var 次數 0)
(def g (gen/map (fn [x] (++ 次數) x) (gen/range 0 100)))
(gen/to-array (gen/take 3 g))
次數    # => 3    ← 不是 100
```

它有 `map` `filter` `keep` `take` `drop` `take-while` `partition` `interleave` `concat`
`cycle` 等 20 支，**名字跟內建的一樣**，所以一定要 `:as gen` 取別名，否則會蓋掉內建的。

**什麼時候用**：資料很大、或你只要前面幾筆、或來源是無窮的（`gen/cycle`）。
一般大小的資料用內建的就好，惰性有它自己的額外成本。

## ⚠ 四、channel/from-each 沒喝完會永遠卡住

`spork/channel` 只有一支函式，但它有個會讓你查很久的行為：

```janet
(import spork/channel)

(def ch (channel/from-each [1 2 3]))   # ⚠ 回傳一個 channel，不是收一個
(ev/take ch)   # => 1
(ev/take ch)   # => 2
(ev/take ch)   # => 3
(ev/take ch)   # => nil   ← 取完了，channel 自動關閉
```

⚠ **沒把它喝完，整個行程就不會結束**：

```janet
(def ch (channel/from-each [1 2 3]))
(ev/take ch)      # 只取一個
# ...程式跑到這裡就掛住了，永遠不會結束
```

實測「取一個就結束」的程式會**無限期停住**（要 `timeout` 才殺得掉）。原因是它背後開了
兩個 fiber 在餵資料，**只有「全部取完」或「主動關閉 channel」才會結束**。

解法：要嘛全部取完，要嘛用完就 `(:close ch)`。

## 五、其餘的：知道有就好

這幾個模組本 repo 沒有實際用到，也**沒辦法離線示範**（都需要真的開 port 或跨行程），
所以這裡只講「它是什麼、什麼時候你會想找它」，細節請看
[官方 spork repo](https://github.com/janet-lang/spork)。

| 模組 | 是什麼 | 什麼時候想到它 |
|------|--------|----------------|
| `spork/stream` | 把 stdin／stdout 包成 ev 串流 | 要**非同步**地一行一行讀 stdin（`stream/lines`） |
| `spork/msg` | 在連線上收發**有長度前綴的訊息** | 自己設計 TCP 協定時，省得處理「一個訊息被切成兩段」 |
| `spork/rpc` | **RPC＝遠端程序呼叫**：像呼叫本地函式一樣呼叫另一台機器上的函式 | 兩個 Janet 行程要互相叫用 |
| `spork/netrepl` | **遠端 REPL**：連到另一個行程的 REPL | 想進到一個**正在跑**的程式裡面看狀態、改東西 |
| `spork/httpf` | 架在 `spork/http` 上的**路由框架** | 要寫多路徑的 HTTP server（單純打 API 看 [17](17-用-spork-http-打-api.md)） |
| `spork/services` | 管理一組長期執行的服務（啟動／停止／列出） | 一個行程裡要跑好幾個背景服務 |
| `spork/tasker` | 帶佇列、優先序、過期時間的**背景工作系統** | 要一個小型 job queue，又不想裝 Redis |

`stream/lines` 是其中唯一能離線示範的：

```sh
printf 'a\nb\nc\n' | janet -e '(import spork/stream)
  (each l (stream/lines (stream/make-stdin)) (prin "[" (string/trim l) "]"))'
# => [a][b][c]
```

## 可跑範例

```sh
janet examples/spork-tour.janet    # pmap 與 generators 都有實測片段
```

下一步：回 [docs 目錄](README.md) 挑下一篇。
