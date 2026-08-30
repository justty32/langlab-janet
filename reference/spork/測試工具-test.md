# 測試工具 ・ spork/test

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/test` 是最陽春的單元測試框架：一個「套件」(suite) 裡塞多個 `assert`，結束時印總結、
有失敗就非零結束（適合塞進 CI）。跟 [斷言與錯誤.md](../斷言與錯誤.md) 的內建 `assert`／`error` 是不同層次的東西：
那份是「程式正常運作時怎麼防呆／怎麼丟錯」，這份是「寫測試腳本時怎麼記錄成功失敗」。

## 核心流程

| 函式 | 簽名 | 說明 |
|---|---|---|
| `test/start-suite` | `(start-suite &opt name)` | 開始一個套件，重置計數器 |
| `test/assert` | `(assert x &opt e)` | 蓋掉內建 `assert`：`x` 為真才算過，`e` 是失敗時的訊息（不給就用 `x` 本身的原始碼字面） |
| `test/assert-not` | `(assert-not x &opt e)` | `assert` 的反向 |
| `test/assert-error` | `(assert-error msg & forms)` | `forms` 執行時**有丟錯**才算過 |
| `test/assert-no-error` | `(assert-no-error msg & forms)` | `forms` 執行時**沒丟錯**才算過 |
| `test/end-suite` | `(end-suite)` | 結束套件、印總結（幾個過幾個），**有失敗就讓程式非零結束** |

```janet
(import spork/test)
(test/start-suite "demo")
(test/assert (= 1 1) "one equals one")
(test/assert-not (= 1 2) "one not equals two")
(test/assert-error "should error" (error "boom"))
(test/assert-no-error "should not error" (+ 1 1))
(test/end-suite)
# => test suite demo finished in 0.000 seconds - 4 of 4 tests passed.
```

失敗長這樣（印到 stderr，紅色 ✘，之後 `end-suite` 讓 process 以非零碼結束）：
```janet
(test/start-suite "fails")
(test/assert (= 1 2) "wrong")
(test/end-suite)
# => ✘ ...: "wrong": false
# => test suite fails finished in 0.000 seconds - 0 of 1 tests passed.
```

## 計數與跳過

| 綁定 | 型別 | 說明 |
|---|---|---|
| `test/skip-asserts` | `(skip-asserts n)` | 接下來 `n` 個 `assert` **不驗證結果、不印訊息**（但仍計入「總數」，見下） |
| `test/num-tests-run` | var（整數） | 目前已經跑過幾個 assert |
| `test/num-tests-passed` | var（整數） | 目前通過幾個 |
| `test/suite-num` | var（整數） | 第幾個套件 |
| `test/skip-count` | var（整數） | 目前被跳過幾個 |
| `test/skip-n` | var（整數） | 還剩幾個要跳過（`skip-asserts` 就是把這個加上去） |
| `test/start-time` | var | 套件開始時間戳 |

⚠ **`skip-asserts` 不會讓「總數」變少**：實測 `(skip-asserts 1)` 後跑兩個 `assert`（第一個故意寫錯、
第二個對），結果是 `1 of 2 tests passed`——被跳過的那個仍然算進「跑過的 2 個」，只是不驗證真假、
不印 ✘／✔，也不影響 pass 計數。以為 `skip-asserts` 等於「總數也少算」的話會對不上帳。

## 輸出與計時輔助

| 函式 | 簽名 | 說明 |
|---|---|---|
| `test/capture-stdout` | `(capture-stdout & body)` | 執行 `body`，回傳 `[body 的回傳值 , 擷取到的 stdout 字串]` |
| `test/capture-stderr` | `(capture-stderr & body)` | 同上，擷取 stderr |
| `test/suppress-stdout` | `(suppress-stdout & body)` | 執行 `body` 但吃掉 stdout（不擷取，單純消音） |
| `test/suppress-stderr` | `(suppress-stderr & body)` | 同上，消音 stderr |
| `test/timeit` | `(timeit form &opt tag)` | 執行 `form`，印出耗時（`tag` 當標籤），回傳 `form` 的值 |
| `test/timeit-loop` | `(timeit-loop head & body)` | 跟 `loop` 語法一樣跑迴圈，跑完印「總耗時／平均每次耗時」 |
| `test/assert-docs` | `(assert-docs path)` | 檢查 `path` 這個模組裡每個綁定是不是都有 docstring |

```janet
(import spork/test)
(test/capture-stdout (print "hi there"))   # => (nil "hi there\n")
(test/timeit (+ 1 2) "sum:")               # 印出 "sum: 0 seconds"，回傳 3
(test/timeit-loop [i :range [0 3]] "loop-tag" (+ i i))
# => 印出 "loop-tag 0.000s, 0.07947µs/body"
```
`test/assert-docs` 實測對 `spork/json` 跑過會回傳一個 tuple（沒細看內部結構之必要，
用途是丟進另一個 `test/assert` 裡當「這個模組每個東西都寫了 docstring」的把關）。
