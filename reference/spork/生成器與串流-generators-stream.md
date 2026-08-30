# 生成器與串流 ・ generators／stream

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/generators` 提供跟內建 `map`／`filter` 同名但**惰性**的版本：回傳的是 **coroutine**（用 `coro` 建的
fiber），要用 `resume` 或 `each` 一個個拉出來，不會一次算完整個結果。跟內建 `generate`（見
[docs/09-fiber.md](../../docs/09-fiber.md)）的差別：`generate` 是**巨集**、用 `loop` 語法自己刻邏輯；
`spork/generators` 是一整組**現成的組合函式**（`map` `filter` `take` `drop`…），跟 `array` 版一一對應好記，
串接起來寫 pipeline 比自己刻 `generate` 好讀。`spork/stream` 則是把 `core/stream`（socket、pipe、檔案）
包成「一行一個 yield」的 fiber。全部函式皆以 `janet -e` 實測於 1.41.2。

## generators

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `from-iterable` | `(from-iterable iterable)` | 把任何可迭代的東西包成 coroutine |
| `range` | `(range from to &opt step)` | 惰性版 `range`，`step` 預設 1 |
| `to-array` | `(to-array iterable)` | 把 coroutine（或任何可迭代物）收集成陣列（會把它跑完） |
| `run` | `(run iterable)` | 只為了副作用把 coroutine 跑完，不收集結果 |
| `concat` | `(concat & iterables)` | 接續吐完第一個再吐第二個…… |
| `map` | `(map f iterable & iterables)` | 惰性版 `map`，可吃多個來源（取最短） |
| `mapcat` | `(mapcat f iterable & iterables)` | `map` 完再攤平一層 |
| `filter` | `(filter pred iterable)` | 只吐 `(pred x)` 為真的 |
| `keep` | `(keep pred iterable & iterables)` | 吐 `(pred x)` 的真值本身 |
| `take` | `(take n iterable)` | 只吐前 `n` 個 |
| `take-while` | `(take-while pred iterable)` | 吐到 `pred` 第一次為假就停 |
| `take-until` | `(take-until pred iterable)` | 吐到 `pred` 第一次為真就停 |
| `drop` | `(drop n iterable)` | 丟掉前 `n` 個，其餘照吐 |
| `drop-while` | `(drop-while pred iterable)` | 丟到 `pred` 第一次為假才開始吐 |
| `drop-until` | `(drop-until pred iterable)` | 丟到 `pred` 第一次為真才開始吐 |
| `cycle` | `(cycle iterable)` | 吐完繞回開頭，無窮迴圈（配 `take` 用，別直接 `to-array`） |
| `interleave` | `(interleave iterable & iterables)` | 輪流吐各來源的第 1、2、3… 個元素（tuple 打包） |
| `interpose` | `(interpose sep iterable)` | 元素間插入 `sep` |
| `partition` | `(partition n iterable)` | 每 `n` 個包成一個陣列吐出 |
| `partition-by` | `(partition-by f iterable)` | `(f x)` 值改變時就切一段新陣列 |

```janet
(import spork/generators :as g)
(pp (g/to-array (g/range 0 5)))                                  # => @[0 1 2 3 4]
(pp (g/to-array (g/take 3 (g/cycle [1 2 3]))))                   # => @[1 2 3]
(pp (g/to-array (g/map + (g/range 0 3) (g/range 10 13))))        # => @[10 12 14]
(pp (g/to-array (g/filter even? (g/range 0 10))))                # => @[0 2 4 6 8]
(pp (g/to-array (g/keep (fn [x] (if (even? x) (* x x))) (g/range 0 6))))
                                                                  # => @[0 4 16]
(pp (g/to-array (g/take-until (fn [x] (= x 3)) (g/range 0 10))))  # => @[0 1 2]
(pp (g/to-array (g/interleave [1 2 3] [:a :b :c])))              # => @[1 :a 2 :b 3 :c]
(pp (g/to-array (g/interpose 0 [1 2 3])))                        # => @[1 0 2 0 3]
(pp (g/to-array (g/partition 2 (g/range 0 5))))                  # => @[@[0 1] @[2 3] @[4]]
(pp (g/to-array (g/partition-by (fn [x] (mod x 3)) [0 3 1 4 2 5])))
                                                                  # => @[@[0 3] @[1 4] @[2 5]]
(g/run (g/map (fn [x] (print "x=" x)) (g/range 0 3)))            # => x=0 / x=1 / x=2（run 不收集）
```

⚠ `from-iterable` 對字串是逐**位元組**吐值：`(g/to-array (g/from-iterable "ab"))` => `@[97 98]`，不是字元。

## stream

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `lines` | `(lines stream &named separator)` | 從 `core/stream` 逐行吐（buffer），預設分隔字元 `\n`；吐完回 `nil`，之後再 `resume` 會丟例外 |
| `make-stdin` | `(make-stdin)` | 開 `/dev/stdin` 當可讀 stream（Windows 不能用） |
| `make-stdout` | `(make-stdout)` | 開 `/dev/stdout` 當可寫 stream（Windows 不能用） |
| `make-stderr` | `(make-stderr)` | 開 `/dev/stderr` 當可寫 stream（Windows 不能用） |

```janet
(import spork/stream)
(def [r w] (os/pipe))          # 用 pipe 造一個 core/stream 來源，離線可測
(ev/write w "a\nb\n")
(ev/close w)
(def lns (stream/lines r))
(print (string (resume lns)))  # => a
(print (string (resume lns)))  # => b
(pp (resume lns))              # => nil   吐完了
(pp (fiber/status lns))        # => :dead
```

⚠ `lines` 吐出來的是 **buffer**，跟 `序列與集合.md` 的提醒一樣，`print` 要自己包 `string`。
`make-stdout`／`make-stderr` 回傳的是真正的 `core/stream`（走 ev 事件迴圈），跟內建 `stdout`／`stderr`
（`core/file`）不是同一種物件，兩者不能混用同一個 `:write`／`ev/write`。
