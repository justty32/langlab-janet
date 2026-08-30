# 並行工具 ・ channel／ev-utils

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/channel` 只有一個函式：把任何可迭代的東西包成 channel。`spork/ev-utils` 是「管理一群 fiber」的工具箱：
nursery 讓一群 fiber 有個共同的生死邊界（結構化並行：母 fiber 死，子全部收掉）；`pmap` 系列是平行版 `map`；
`pdag` 依「誰要等誰做完」平行跑一張圖；`multithread-service` 是常駐、會自動重啟的多執行緒服務。全部函式皆以
`janet -e` 實測於 1.41.2。

## channel

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `from-each` | `(from-each iterable &named supervisor)` | 把 `iterable` 包成 channel，邊被 `ev/take` 邊供下一個，channel 關閉表示供完 |

```janet
(import spork/channel)
(def ch (channel/from-each [1 2 3]))
(pp (ev/take ch))   # => 1
(pp (ev/take ch))   # => 2
(pp (ev/take ch))   # => 3
(pp (ev/take ch))   # => nil   供完之後 channel 關閉，take 回 nil
```

## ev-utils ・ 結構化並行（nursery）

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `nursery` | `(nursery)` | 建一個「fiber 群組」，回傳 `@{:supervisor :fibers}` |
| `go-nursery` | `(go-nursery nurse f &opt value)` | 像 `ev/go`，但把新 fiber 掛進 nursery |
| `spawn-nursery` | `(spawn-nursery nurse & body)` | `go-nursery` 的巨集版，直接寫 body |
| `join-nursery` | `(join-nursery nurse)` | 卡住目前 fiber，等 nursery 裡全部 fiber 跑完；任一個出錯，其餘全被取消 |
| `wait-cancel` | `(wait-cancel & body)` | 巨集：目前 fiber 一直睡到被 `ev/cancel`，取消時才跑 `body`（清理碼） |

```janet
(import spork/ev-utils :as eu)
(def n (eu/nursery))
(eu/spawn-nursery n (ev/sleep 0.05) (print "A 完成"))
(eu/go-nursery n (fn [&] (ev/sleep 0.02) (print "B 完成")))
(eu/join-nursery n)
(print "全部完成")
# => B 完成
#    A 完成
#    全部完成
```

⚠ `join-nursery` 不保證順序——先睡醒的先印，這裡 B（0.02s）比 A（0.05s）先完成。

`wait-cancel` 要搭配會取消它的 supervisor 才看得出效果：

```janet
(def sup (ev/chan))
(def f (ev/go (fn [] (eu/wait-cancel (print "被取消時清理"))) nil sup))
(ev/cancel f "done")
(ev/take sup)
# => 被取消時清理     （先印出清理訊息，defer 保證清理碼一定跑）
```

## ev-utils ・ 平行版 map／call

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `pcall` | `(pcall f n)` | 平行呼叫 `f` `n` 次，`f` 收到 0..n-1 的索引，回傳 `nil`（只做副作用用） |
| `pmap-full` | `(pmap-full f data)` | 對 `data`（陣列或字典）每個元素平行套 `f`，任一錯全部取消，回傳結果 |
| `pmap-limited` | `(pmap-limited f data n-workers)` | 同 `pmap-full`，但限制同時只有 `n-workers` 個在跑 |
| `pmap` | `(pmap f data &opt n-workers)` | 不給 `n-workers` 就是 `pmap-full`，給了就是 `pmap-limited` |

```janet
(pp (eu/pmap (fn [x] (* x x)) [1 2 3 4 5]))     # => @[1 4 9 16 25]         全平行
(pp (eu/pmap (fn [x] (* x x)) [1 2 3 4 5] 2))   # => @[1 4 9 16 25]         限 2 個 worker
(pp (eu/pcall (fn [i] (print "worker " i)) 3))
# => worker 0 / worker 1 / worker 2（順序不定）之後回 nil
```

## ev-utils ・ 依賴圖與多執行緒

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `pdag` | `(pdag f dag &opt n-workers)` | `dag` 是 `{節點 [它依賴的節點...]}`，依賴都跑完才輪到它，回傳 `{節點 (f 節點)}` |
| `multithread-service` | `(multithread-service thread-main n-threads)` | 起 `n-threads` 個常駐執行緒跑 `thread-main`；哪個掛了就重啟哪個，正常結束才算數 |

```janet
(def dag {:a [] :b [:a] :c [:a] :d [:b :c]})
(pp (eu/pdag (fn [n] (print "run " n) n) dag))
# => run a / run b / run c / run d   （a 一定最先，d 一定最後，b c 順序不定）
#    @{:a :a :b :b :c :c :d :d}
```

⚠ `multithread-service` 是**無窮迴圈**（每條執行緒正常結束才 `-- to-complete`，異常結束會重啟、永遠不會自然停下）；
除非 `thread-main` 自己會正常 return，否則這函式不會回傳。真的要跑得自己開一個獨立行程測，這裡不示範。
