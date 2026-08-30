# 28 · spork/misc 順手工具

`spork/misc` 是 42 個**「早該內建但沒有」**的小工具。它沒有主題，就是雜貨店——
但裡面有幾樣東西補的是**內建真的很難用的地方**，值得先知道有它們在，不然你會自己重寫一遍。

```janet
(import spork/misc)
```

這篇只講**你會後悔沒早點知道**的那些；42 個的逐一筆記在
[`reference/spork/misc-順手工具.md`](../reference/spork/misc-順手工具.md)。

## 一、字典操作：這是 misc 最重要的一段

[25 序列工具](25-序列工具.md) 講過內建序列函式的規則——**輸出幾乎都是 array**。
套在字典上就很痛：

```janet
(map inc {:a 1 :b 2})    # => @[3 2]   ← key 全沒了，而且順序還不保證
```

你想要的是「**改值但保持字典形狀**」。`misc` 補的正是這個洞：

```janet
(misc/map-vals inc {:a 1 :b 2})            # => @{:a 2 :b 3}   ← key 留著
(misc/map-keys string {:a 1})              # => @{"a" 1}       ← 換 key
(misc/select-keys {:a 1 :b 2 :c 3} [:a :c]) # => @{:a 1 :c 3}   ← 挑幾個欄位
(misc/table-filter (fn [k v] (> v 1)) @{:a 1 :b 2})  # => @{:b 2}
```

⚠ 注意 `table-filter` 的判斷函式收的是 **`[k v]` 兩個參數**，不是一個。

還有一支深層取值，比 `get-in` 少打一對括號：

```janet
(misc/gett {:a {:b {:c 42}}} :a :b :c)   # => 42
(get-in {:a {:b {:c 42}}} [:a :b :c])    # => 42   內建版，key 要包成陣列
```

## 二、洗牌：不要自己寫

```janet
(misc/randomize-array @[1 2 3 4 5])                        # 原地洗，回同一個陣列
(misc/randomize-array (array ;(range 10)) (math/rng 2026)) # 給 rng => 可重現
```

這就是 Fisher-Yates。⚠ 而且它**不給 rng 時預設用 `(math/rng (os/cryptorand 8))`**——
所以跨行程真的每次不同，**跟裸的 `math/random` 相反**（見 [26 隨機數](26-隨機數.md) 那個坑）。

## 三、取元素與排序

```janet
(misc/second [1 2 3])          # => 2      內建只有 first / last
(misc/third [1 2 3])           # => 3
(misc/penultimate [1 2 3 4])   # => 3      倒數第二
(misc/antepenultimate [1 2 3 4])  # => 2   倒數第三
```

**已排序**的陣列上有三支效率好的：

```janet
(misc/binary-search 3 [1 2 3 4 5])   # => 2   回索引；⚠ 前提是已排序
(misc/insert-sorted @[1 3 5] < 4)    # => @[1 3 4 5]   插進去仍保持排序
(misc/merge-sorted [1 3 5] [2 4 6])  # => @[1 2 3 4 5 6]
```

> **二分搜尋**＝每次砍一半地找，比從頭掃快得多，但**前提是資料已經排好序**。
> 傳沒排序的進去不會報錯，只會給你錯的答案。

## 還有一半：文字、表格與流程

字串小工具（`trim-prefix`／`dedent`／進位轉換）、印表格、捕捉 stdout、
`cond->`／`until`、以及一個設計得很聰明的 logger——另成一篇：
[28b spork/misc 文字與流程](28b-spork-misc-文字與流程.md)。

## 可跑範例

```sh
janet examples/spork-tour.janet    # misc 與其他十三個模組各跑一段
```

下一步：[28b spork/misc 文字與流程](28b-spork-misc-文字與流程.md)。