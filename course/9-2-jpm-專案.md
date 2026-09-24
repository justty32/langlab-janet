# 9-2 · jpm 專案

一支檔的程式，`janet x.janet` 就能跑。可是當程式拆成好幾支檔、要寫測試、還想交一個別人不用裝 Janet 也能跑的執行檔時，就需要一個「專案」把這些事管起來。這課教你讀懂一個 jpm 專案、會用日常的幾個指令，並避開它最常咬人的幾個坑。

## 這是什麼、為什麼

jpm 是 Janet 的專案管理員，角色跟 Node 的 npm、Rust 的 cargo 差不多：幫你裝套件、跑測試、編執行檔。每個專案的根目錄有一支 `project.janet`，寫著「這專案叫什麼、有哪些檔、要編出什麼」。

但 jpm 的骨子比較像 C 世界的 `make`。它內部是一堆 rule（規則：「要做出某個東西，得先有哪些東西、然後跑哪段程式」），`jpm build`、`jpm test` 這些指令其實就是「去跑名叫 build、test 的 rule」。這個比喻不完全準：你平常不用自己寫 rule，`project.janet` 裡的宣告會替你生出來。但記住「它是 make」，後面幾個坑就說得通。

什麼時候才需要專案？一支檔、自己跑跑的小工具，直接 `janet x.janet` 就好，不必弄專案。要拆多檔、要 `jpm test`、要交執行檔、要讓別人 `import` 你的程式時，才值得開一個。

## 動手

### 專案長怎樣

課程附了一個最小的示範專案 `examples/course/9-demo/`。在那個目錄裡列出所有檔：

```sh
cd examples/course/9-demo
find . -type f | sort
```

```text
./bin/main.janet
./demo/init.janet
./project.janet
./test/basic.janet
./test/with-spork.janet
```

每個位置的用途：

| 位置 | 放什麼 |
|------|--------|
| `project.janet` | 專案說明書，jpm 只認這支檔 |
| `demo/` | 真正的程式邏輯，別人 `import` 的就是這裡 |
| `bin/main.janet` | 執行檔的進入點（程式從這裡開始跑） |
| `test/` | 測試，`jpm test` 會把這裡每支 `.janet` 跑一遍（下一課細講） |
| `build/` | `jpm build` 產出的東西，不要手改、不要進版控，這裡平常不存在 |

`demo/init.janet` 裡只有三個小函式 `add`、`greet`、`count-words`。`bin/main.janet` 用 9-1 教過的相對路徑把它 import 進來用：

```janet
(import ../demo/init :as demo)

(defn main [& args]
  # args 的第 0 個是程式自己，使用者給的參數從第 1 個開始
  (def name (get args 1))
  (print (demo/greet name))
  (printf "1 + 2 = %d" (demo/add 1 2)))
```

### project.janet 的三個宣告

整支 `project.janet` 長這樣：

```janet
(declare-project
  :name "demo"
  :description "課程單元 9 的示範專案"
  :version "0.1.0"
  :dependencies ["spork"])

(declare-source
  :prefix "demo"
  :source ["demo/init.janet"])

(declare-executable
  :name "demo"
  :entry "bin/main.janet"
  :install false)
```

這三個東西只在 jpm 讀這支檔時才存在，你在一般的 `janet` 裡叫不到它們。逐個看：

`declare-project` 是專案的身分證：名字、一句說明、版本，還有 `:dependencies`（依賴，這專案要用到的別人的套件）。這裡寫了 `"spork"`，所以 `jpm deps` 會去裝 spork。

`declare-source` 說「哪些檔是給別人 import 的」。`:source` 要一支一支列出檔名；`:prefix "demo"` 表示裝好之後，別人寫 `(import demo/init)` 就能用。⚠ `:source` 別偷懶給目錄名，後面的坑會講為什麼。

`declare-executable` 說「要編出一個執行檔」：`:entry` 是進入點那支檔，`:name` 是產物的名字，編好會在 `build/demo`。`:install false` 表示 `jpm install` 時不要把它裝到系統上，只留在 `build/`。

### main 會被自動呼叫

`bin/main.janet` 裡沒有任何一行去呼叫 `main`，那它怎麼會跑？規則是：`janet 某檔.janet` 把整支檔從頭到尾跑完之後，如果檔裡有定義叫 `main` 的函式，就自動呼叫它，並把命令列參數傳進去。

範例檔 `examples/course/9-2.janet` 把這件事拆開給你看。它的頂層（不在任何函式裡的程式碼）印兩行，然後定義 `main`：

```sh
janet examples/course/9-2.janet Ann 42
```

```text
== 頂層程式碼 ==
載入這支檔就會印這行（被 import 也會）
== main ==
main 收到 3 個參數：("examples/course/9-2.janet" "Ann" "42")
第 0 個是程式自己：examples/course/9-2.janet
使用者給的：("Ann" "42")
```

看到三件事。頂層程式碼比 `main` 早跑。`args` 的第 0 個是腳本自己的路徑，使用者打的從第 1 個開始，跟 C 的 `argv` 一樣。參數全是字串，`42` 也是 `"42"`。

換成別人 `import` 這支檔，頂層照樣會跑，但 `main` 不會被呼叫：

```sh
janet -e '(import ./examples/course/9-2 :as ex) (print "import 完了，main 沒被呼叫")'
```

```text
== 頂層程式碼 ==
載入這支檔就會印這行（被 import 也會）
import 完了，main 沒被呼叫
```

所以會被 import 的檔，頂層只放定義，要「做事」的程式碼收進 `main`。這跟 Python 的 `if __name__ == "__main__":` 是同一個用意。

日常指令在續篇：[9-2b · jpm 日常指令](9-2b-jpm-專案.md)
