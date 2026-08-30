# 23b · 用 spork/test 寫測試

[← 23 測試怎麼寫](23-測試怎麼寫.md) 講的是**內建 `assert`** 那條路——夠用、零依賴。
這篇講 `spork/test`：它解掉了內建那套**最惱人的一個限制**。

```janet
(import spork/test)
```

## 它解決什麼：一條壞掉不再遮住後面

[23 提過](23-測試怎麼寫.md)：內建 `assert` 一失敗就**丟例外、整支檔案停在那裡**，
後面的斷言全都不會跑。所以你修好第一個問題、再跑、才看到第二個問題，一次一個慢慢挖。

`spork/test` 的 `assert` **失敗只記一筆然後繼續跑**：

```janet
(test/start-suite "會失敗的")
(test/assert (= 4 (+ 2 2)) "這條會過")
(test/assert (= 5 (+ 2 2)) "這條會失敗")
(test/assert (= 6 (+ 3 3)) "失敗之後還是會跑")
(test/end-suite)
```

```
✘ t2.janet:4: "這條會失敗": false
test suite 會失敗的 finished in 0.000 seconds - 2 of 3 tests passed.
```

**一次就看到全部災情。**失敗那行會印出**檔名:行號、你給的訊息、實際的值**。

## 跟 jpm test 怎麼搭

`end-suite` 在**有任何一條失敗時會讓行程以非 0 結束**（實測 exit code = 1），
所以 [`jpm test`](05-jpm-與專案.md) 照樣抓得到失敗，不用改任何設定。

換句話說：**你只是把 `assert` 換成 `test/assert` 並包上 suite，其餘工作流程不變。**

## 五種斷言

```janet
(test/assert x "訊息")              # 跟內建一樣，但不中止
(test/assert-not x "訊息")          # 反過來
(test/assert-error "訊息" (可能爆的東西))     # 斷言「這件事該爆」
(test/assert-no-error "訊息" (不該爆的東西))  # 斷言「這件事不該爆」
```

`assert-error` 比 [23 教的 `protect` 寫法](23-測試怎麼寫.md)短很多——
不用自己解 `[ok e]`，也不會忘記檢查 `ok`。

## 抓輸出與測時間

```janet
(test/capture-stdout (print "被抓走了"))
# => (nil @"被抓走了\n")     ← [body 的回傳值  抓到的輸出]

(test/suppress-stdout (print "看不見") :回傳值)
# => :回傳值                 ← 只是把輸出丟掉，回傳值照給

(test/timeit (reduce + 0 (range 100000)) "加總十萬")
# 印出：加總十萬 0.00655746459960938 seconds
```

`capture-stdout` 回的是**兩格 tuple**（回傳值在前、輸出在後），別搞反。
另有 `capture-stderr`、`suppress-stderr`、以及跑很多次取平均的 `timeit-loop`。

計時的注意事項（哪種時鐘、為什麼不能用牆上時鐘）見 [24 時間與日期](24-時間與日期.md)。

## ⚠ 兩個會咬人的地方

### 一、`skip-asserts` 會讓整個 suite 變成失敗

看名字你會以為它是「暫時跳過這幾條」，像別的框架的 `xit`／`@Ignore`。**不是。**

```janet
(test/skip-asserts 2)
(test/assert (= 4 (+ 2 2)) "本來會過1")
(test/assert (= 4 (+ 2 2)) "本來會過2")
(test/assert (= 4 (+ 2 2)) "沒被跳過")
```

```
test suite skip-true finished in 0.000 seconds - 1 of 3 tests passed.
exit code = 1
```

被跳過的兩條**算進「跑了幾條」，但永遠不算「過了幾條」**——即使它們本來會過。
結果就是**你的測試變紅**。實測跳過「本來會失敗」和「本來會過」的斷言，
結果一模一樣，可見它跟斷言本身的真假無關。

⚠ 所以**不要拿它當「暫時停用」用**。真的要停用就把那幾行註解掉，或搬到另一支檔案。

### 二、中文訊息在失敗輸出裡會變成一串 `\xE9\x80\x99`

```
✘ t2.janet:4: "\xE9\x80\x99\xE6\xA2\x9D\xE6\x9C\x83\xE5\xA4\xB1\xE6\x95\x97": false
✘ t3.janet:3: "ascii message here": false
```

失敗訊息是用 Janet 表示法印的，**非 ASCII 會被逃逸**（跟
[01 的 print vs pp](01-語言速成.md)、`%q` 是同一個坑）。訊息本身沒壞，只是看不懂。

**繞法**：失敗訊息**寫成 ASCII**（`"port must be a number"`），
或接受它、反正 `檔名:行號` 已經足夠定位。本 repo 內建 `assert` 那套沒有這個問題——
它是直接把字串當錯誤訊息丟出來，中文顯示正常。

## 該用哪一套

| 情況 | 用 |
|------|-----|
| 一支小測試、不想多一個依賴 | **內建 `assert`**（[23](23-測試怎麼寫.md)） |
| 錯誤訊息要中文 | **內建 `assert`** |
| 一支檔案裡有很多條斷言，想一次看到全部失敗 | **`spork/test`** |
| 要斷言「這該爆／這不該爆」 | **`spork/test`** 的 `assert-error`／`assert-no-error` |
| 要抓 stdout 或量執行時間 | **`spork/test`**（或 `spork/misc` 的 `capout`，見 [28b](28b-spork-misc-文字與流程.md)） |

⚠ **兩套可以混用**：`spork/test` 沒有接管任何東西，同一支檔案裡照樣能用內建 `assert`。
本 repo 目前的 `test/` 全部走內建那套（見 [`test/util.janet`](../test/util.janet)），
因為測試量不大、而且訊息要中文。

## 可跑範例

```sh
janet examples/testing-demo.janet    # 內建 assert 那套的示範（23）
```

`spork/test` 的完整函式清單在
[`reference/spork/測試工具-test.md`](../reference/spork/測試工具-test.md)。

下一步：[24-時間與日期.md](24-時間與日期.md)。
