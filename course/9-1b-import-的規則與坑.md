# 9-1b · import 的規則與坑

[← 9-1 · import 與拆檔](9-1-import-與拆檔.md)

上一篇講了路徑怎麼寫。這篇把剩下的規則補完：import 要放哪裡、同一支模組會不會跑兩次、哪些名字拿不到，再把最常見的坑一個一個拆開。

## 動手（續）

### import 要放在最外層

最外層（頂層）的意思是「不在任何函式、`let` 裡面」，就是檔案最左邊那一排。import 一定要寫在那裡。

先看錯的寫法，`bad.janet`：

```janet
(defn show []
  (import ./lib/greet)
  (print (greet/hello "小明")))
(show)
```

```sh
janet bad.janet
```

```text
bad.janet:3:10: compile error: unknown symbol greet/hello
```

Janet 跑一支檔是一段一段來：先把一段程式碼編譯（翻成機器能跑的形式），再執行。編譯 `show` 這個函式時，裡面的 `import` 還沒跑過，`greet/hello` 這個名字根本不存在，所以第 3 行直接編譯失敗，連 `(show)` 都輪不到。放在頂層就不會，因為上一段 import 跑完，下一段才開始編譯。

### 模組只會載入一次

`9-1.janet` 裡 `greet` 和 `math` 都被 import 了好幾次，可是「（greet.janet 被載入了）」只印一次。Janet 把跑過的模組記在 `module/cache` 這張表裡，第二次 import 同一支檔，直接拿上次跑完的結果，不會重跑。

所以你不用像 C 那樣寫 include guard，重複 import 沒有成本。反過來，模組檔改了之後，已經在跑的程式不會自己發現，要重開。

### 私有的名字拿不到

`def-`、`defn-` 定義的是私有名字，只有模組自己能用。`9-1-lib/math.janet`：

```janet
(defn square [x] (* x x))
(defn- helper [x] (+ x 1))
(defn square+1 [x] (helper (square x)))
```

```text
私有的 helper 進不來：nil
但公開的 square+1 可以用它：10
```

`helper` 沒被抄過來，找不到就是 `nil`。但公開的 `square+1` 在模組裡照樣能呼叫 `helper`。這跟 JS 裡沒 `export` 的函式一樣。

### use：全部倒進來

`(use ./9-1-lib/greet)` 等於不加前綴的 import，模組裡所有公開名字直接進來，可以寫 `(hello "阿華")`。短小的腳本很方便，但名字一多就分不清誰是誰，而且會把你沒想要的名字（例如模組自己的 `main`）也帶進來，這個坑留到 9-2 講。一般還是用 `import` 加 `:as`。

## 你會踩的坑

⚠ `~` 不是家目錄

你會以為：`(import ~/repo/mylib)` 就是「我家目錄底下的 repo/mylib」。

其實是：拿到一個看不懂的錯誤。

```text
could not find module <tuple 0x555A7C8F9180>:
```

因為：`~` 在 Janet 是 quasiquote（一種「先別執行，把後面這段程式碼原樣留著」的符號，10-4 巨集那課會細講）。`~/repo/mylib` 在讀進來的那一刻就變成一個 tuple（一串放進去就不能改的值），不是字串，也不是路徑。

```janet
(type '~/repo/x)   # => :tuple
```

錯誤訊息裡的 `0x…` 是記憶體位址，每次跑都不一樣。看到 `<tuple 0x…>` 就知道是 `~`。要從家目錄拿檔，用相對路徑數 `../`，或把模組裝進系統模組路徑（見 9-2）。

⚠ 開頭 `/` 的絕對路徑會被吃掉

你會以為：`(import /home/我/lib/x)` 用絕對路徑最保險。

其實是：Janet 去找 `home/我/lib/x.janet`，開頭的 `/` 不見了，變成相對你目前目錄的路徑。

因為：import 只認得 `./`、`../` 開頭的相對路徑，和系統模組路徑。真的只有絕對路徑時，改用 `(dofile "/絕對/路徑.janet")`，它吃的是一般的檔案路徑，但不走快取，每次都重跑。

⚠ import 放在函式裡

你會以為：用到的時候再 import，跟 Python 在函式裡 `import` 一樣。

其實是：`compile error: unknown symbol`，連函式都建不起來。

因為：Janet 編譯函式時就要知道每個名字是什麼，那時函式裡的 import 還沒執行。上面「import 要放在最外層」那段有實測。

⚠ 忘了 `./`

你會以為：`(import greet)` 會找同一個資料夾的 `greet.janet`，跟 Python 一樣。

其實是：`could not find module greet`，後面列出的位置全在 `/home/…/.local/lib/janet/` 底下。

因為：沒有 `./`、`../` 開頭的名字，Janet 一律當成系統模組，只去 `(dyn :syspath)` 找。自己的檔要寫 `(import ./greet)`。

## 小練習

1. 用 `:as mt` import `9-1-lib/math`，印出 12 的平方。
2. 同事寫了 `(import ~/repo/x)` 跑不動。跟他解釋為什麼，並說要改成什麼。
3. 在 `/tmp` 底下用絕對路徑跑 `janet /…/examples/course/9-1.janet`，猜猜找不找得到 `greet`？為什麼？

答案在 `examples/course/9-1.janet` 最後的「練習解答」。

## 想更深

- [docs/05e import 與模組路徑](../docs/05e-import-與模組路徑.md)：五條路徑規則的速查版，還有門面檔 `init` 的實例。
- [docs/05d 引用自己的專案](../docs/05d-引用自己的專案.md)：跨 repo 引用自己的另一個專案、`jpm install` 本地 repo 的兩個前提。
- [snippets/import-files/main.janet](../snippets/import-files/main.janet)：跑起來就是一份教材，多了 `merge-module` 挑名字、`require` 執行期載入、`dofile` 的差別。

下一課：[9-2 · jpm 專案](9-2-jpm-專案.md)
