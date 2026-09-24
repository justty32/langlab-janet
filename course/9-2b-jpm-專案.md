# 9-2b · jpm 日常指令

接續 [9-2 · jpm 專案](9-2-jpm-專案.md)。以下指令都在 `examples/course/9-demo/` 裡實際跑過。

## 動手（續）

### 開發期：直接跑，不用 build

```sh
janet bin/main.janet Ann
```

```text
Hello, Ann!
1 + 2 = 3
```

寫程式的時候這樣跑就好，改完馬上看到結果。`build` 是要交出去時才做的事。

### jpm test：跑測試（這個專案會先 build）

```sh
jpm test
```

```text
generating executable c source build/demo.c from bin/main.janet...
compiling build/demo.c to build/build___demo.o...
linking build/demo...
running test/basic.janet ...
basic 測試通過
running test/with-spork.janet ...
test suite demo finished in 0.000 seconds - 5 of 5 tests passed.
✓ All tests passed.
```

前三行在編執行檔，不是在測試。原因是 test 這條 rule 依賴 build 這條 rule，只要專案有 `declare-executable`，`jpm test` 就會先編一次。用 `jpm rule-tree` 看得到這層關係：

```text
test
 └─build
    └─build/demo
       └─bin/main.janet
```

測試本身跑的還是 `test/` 裡的原始碼，不是編出來的執行檔。怎麼寫測試是下一課的事。

### jpm build：編成執行檔

```sh
jpm build
./build/demo Ann
```

```text
generating executable c source build/demo.c from bin/main.janet...
compiling build/demo.c to build/build___demo.o...
linking build/demo...
Hello, Ann!
1 + 2 = 3
```

jpm 先把你的程式轉成一支 C 檔，再用 C 編譯器編成 `build/demo`。這支檔自帶 Janet，拿到沒裝 Janet 的同型機器上也能跑。

### jpm clean、jpm deps、jpm rules

```sh
jpm clean
```

```text
Deleted build directory build
```

`jpm clean` 把整個 `build/` 刪掉。`jpm deps` 會照 `:dependencies` 去裝 spork；這台機器已經裝過，所以它什麼都沒印，直接結束。`jpm rules` 列出這個專案所有的 rule：

```text
/home/lorkhan/.local/lib/janet/.manifests/demo.jdn
build
build/demo
clean
install
manifest
test
uninstall
```

第一行那條長路徑是 install 時要寫的安裝紀錄檔，也是一條 rule。

### jpm run 跑的是 rule，jpm install 裝到哪

`jpm run X` 的意思是「跑名叫 X 的 rule」，所以 `jpm run build` 就等於 `jpm build`。想要「編完就執行」，得在 `project.janet` 自己加一條 phony rule（phony：不產出檔案、只做事的 rule），這留給小練習。

開新專案用 `jpm new-project 名字`（純函式庫）或 `jpm new-exe-project 名字`（帶執行檔），它們會替你生好目錄骨架。

`jpm install 套件名` 會把套件裝到 `(dyn :syspath)` 指的目錄，之後任何地方都能 `import`：

```sh
janet -e '(print (dyn :syspath))'
```

```text
/home/lorkhan/.local/lib/janet
```

spork 就裝在這底下的 `spork/`。你的路徑會不一樣，看你怎麼裝 Janet。

坑、小練習、想更深在續篇：[9-2c · jpm 會咬人的地方](9-2c-jpm-專案.md)
