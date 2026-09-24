# 9-3b · 測試配方與 spork/test

[上一篇](9-3-寫測試.md)學會了內建 `assert` 和 `jpm test`。這篇先給三個天天會用到的檢查寫法，再介紹 spork/test：一條失敗不會讓整支檔停下來的那套工具。

## 三種常用配方

### 比 array、table：用 deep=

```janet
(= @[1 2] @[1 2])   # => false
(deep= @[1 2] @[1 2])   # => true
(= [1 2] [1 2])   # => true
```

`=` 碰到 array、table 這類可變容器，比的是「是不是同一個東西」，不是內容（3-3 講過）。兩個各自建出來的 `@[1 2]` 是兩個東西，所以 `=` 說不等。測試裡比集合一律用 `deep=`。tuple 本來就比內容，用 `=` 沒問題。

### 驗「這件事該失敗」：用 protect

```janet
(defn parse-port [s]
  (or (scan-number s) (error "port is not a number")))

(def [ok e] (protect (parse-port "abc")))
(assert (not ok) "bad input should error")
(assert (= e "port is not a number") "error message")
ok   # => false
```

`protect` 把錯誤接成 `[false 錯誤訊息]`，第一格是 `false` 代表真的爆了。兩條都要檢查：先確認有爆，再確認爆的原因對。

⚠ 挑「該失敗」的例子前先試試它真的會爆。Janet 很多你以為會出錯的事其實不會：

```janet
(print (/ 1 0))
# 印出：inf
(= (/ 1 0) math/inf)   # => true
(get nil :a)   # => nil
```

除以零得到無限大，對 `nil` 取值得到 `nil`，都不是錯誤。拿它們寫「該失敗」的測試，這條測試永遠不會紅，等於沒寫。

### 浮點數：比差值

```janet
(= (+ 0.1 0.2) 0.3)   # => false
(< (math/abs (- (+ 0.1 0.2) 0.3)) 1e-9)   # => true
```

跟 C、Python、JS 一樣，浮點數有誤差。檢查「兩數夠接近」，不要用 `=`。

## spork/test：失敗了照樣跑完

spork 是 Janet 官方的擴充函式庫（9-2 的 `:dependencies ["spork"]` 就是它），裡面的 `spork/test` 是一組測試小工具。它跟內建 `assert` 最大的不同：失敗只記一筆，繼續跑下一條，最後一起結算。

示範專案的 `test/with-spork.janet`：

```janet
(import spork/test :as t)
(import ../demo/init :as demo)

(t/start-suite "demo")
(t/assert (= (demo/add 2 2) 4) "2 + 2 = 4")
(t/assert (= (demo/greet "Ann") "Hello, Ann!") "greet with name")
(t/assert-not (empty? (demo/greet)) "greet is never empty")
(t/assert-error "add needs numbers" (demo/add 1 "x"))
(t/assert-no-error "count-words handles empty string" (demo/count-words ""))
(t/end-suite)
```

`start-suite` 開始計數，`end-suite` 印出「幾條裡過了幾條」。上一篇的 `jpm test` 輸出裡 `5 of 5 tests passed` 就是它印的。五種斷言各做一件事：

- `t/assert`：條件要成立，跟內建的一樣，只是失敗不停。
- `t/assert-not`：條件要不成立。
- `t/assert-error`：後面的程式該爆。訊息寫在前面。
- `t/assert-no-error`：後面的程式不該爆。
- `t/capture-stdout`：不是斷言，是把 `print` 的輸出抓下來給你檢查。

`assert-error` 幫你省掉 `protect` 解 `[ok e]` 那段，但只管有沒有爆，不看錯誤訊息。

`capture-stdout` 回傳兩格：回傳值在前，印出的字在後。

```janet
(import spork/test :as t)
(def [ret out] (t/capture-stdout (print "hi") 42))
(printf "ret = %j, out = %j" ret out)
# 印出：ret = 42, out = "hi\n"
```

### 有失敗時長這樣

在複製出來的專案裡放一支 `test/c-spork-bad.janet`，四條裡寫錯兩條：

```janet
(import spork/test :as t)
(import ../demo/init :as demo)

(t/start-suite "bad")
(t/assert (= (demo/add 1 2) 3) "add works")
(t/assert (= (demo/add 1 2) 4) "add is wrong on purpose")
(t/assert (= (demo/greet) "Hello, world!") "still runs after a failure")
(t/assert (= (demo/greet) "Hi") "greet message")
(t/end-suite)
```

`jpm test` 裡這支的部分：

```text
running test/c-spork-bad.janet ...
✘ test/c-spork-bad.janet:6: "add is wrong on purpose": false
✘ test/c-spork-bad.janet:8: "greet message": false
test suite bad finished in 0.000 seconds - 2 of 4 tests passed.
non-zero exit code in test/c-spork-bad.janet: 1
```

兩條錯一次全列出來，各附檔名和行號，第 7 行那條照樣跑了。`end-suite` 發現有失敗就讓行程 exit 1，所以 `jpm test` 一樣抓得到，不用改任何設定。（終端機裡 `✘` 是紅色的。）

訊息故意寫英文，下一篇會說為什麼。

續篇：[9-3c · 選哪套與會踩的坑](9-3c-選哪套與會踩的坑.md)
