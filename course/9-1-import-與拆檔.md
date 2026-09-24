# 9-1 · import 與拆檔

程式長到幾百行，全塞在一支檔裡會越來越難找東西。這課教你把程式拆成好幾支 `.janet` 檔，再用 `import` 把別支檔的函式拿過來用。學完你會知道路徑怎麼寫才找得到檔，以及幾個第一次一定會踩的坑。

## 這是什麼、為什麼

拆檔的理由跟你在 C、Python、JS 裡一樣：同一類功能放一起，別的程式想用就拿，不用複製貼上。

在 Janet 裡，一支被別人拿來用的 `.janet` 檔叫模組（module）。`import` 做的事不是 C 的 `#include` 那種「把文字原封不動貼過來」，而是：

1. 找到那支檔，從頭到尾跑一遍。
2. 跑完之後，那支檔定義的名字都記在它自己的 env（一張「名字對應到值」的表）裡。
3. 把那張表裡公開的名字，加上一個前綴，抄進你這支檔。

所以它比較像 Python 的 `import greet`：你拿到的是 `greet.hello`，在 Janet 寫成 `greet/hello`。

## 動手

這課的範例在 `examples/course/9-1.janet`，它旁邊有個資料夾 `9-1-lib/`，放兩支很短的模組。

### 基本 import

`examples/course/9-1-lib/greet.janet` 的內容：

```janet
(print "（greet.janet 被載入了）")
(def- 招呼語 "你好")
(defn hello [name] (string 招呼語 "，" name))
```

第一行的 `print` 是故意放的，讓你看得到「這支檔什麼時候被跑」。`def-` 後面多一個減號，意思是私有，等一下會講。

`9-1.janet` 裡這樣用它：

```janet
(import ./9-1-lib/greet)
(print (greet/hello "小明"))
```

```text
（greet.janet 被載入了）
你好，小明
```

路徑 `./9-1-lib/greet` 的最後一段是 `greet`，所以前綴就是 `greet/`。模組裡的 `hello` 到你這邊變成 `greet/hello`。前綴的好處是不同模組都有 `hello` 也不會打架。

### 自己取前綴：:as 與 :prefix

```janet
(import ./9-1-lib/math :as m)       # 前綴改成 m/
(print (m/square 5))                # 印出：25
(import ./9-1-lib/math :prefix "")  # 不加前綴
(print (square 6))                  # 印出：36
```

`:as m` 把前綴換成你想要的短名字。`:prefix ""` 則是完全不加前綴，名字直接進來。

平常建議給 `:as`。原因是很多模組的入口檔都叫 `init.janet`（像 Python 套件的 `__init__.py`），不給 `:as` 會得到一堆 `init/ask`、`init/run`，讀的人根本不知道 `init` 是誰。`:prefix ""` 方便，但名字一多就分不出哪個是從哪來的。

### 相對路徑，相對的是「寫這行的那支檔」

這是 Janet 最容易讓人誤會的一點。`./9-1-lib/greet` 的 `./` 指的是 `9-1.janet` 自己所在的資料夾，跟你在哪個目錄下指令沒有關係。

實際試兩種跑法：

```sh
janet examples/course/9-1.janet            # 在 repo 根目錄跑
cd examples/course && janet 9-1.janet      # 先切進去再跑
```

兩次都找得到模組，印出的內容也一樣，只有路徑的寫法不同。範例檔有一段會印出目前載入了哪些模組，第一種跑法看到：

```text
這支檔：examples/course/9-1.janet
已載入：examples/course/9-1-lib/greet.janet
已載入：examples/course/9-1-lib/math.janet
```

第二種跑法看到：

```text
這支檔：9-1.janet
已載入：9-1-lib/greet.janet
已載入：9-1-lib/math.janet
```

Janet 是從「這支檔的位置」往下找 `9-1-lib/`，再把結果寫成相對你目前目錄的樣子。你甚至可以 `cd /tmp` 再用絕對路徑跑這支檔，一樣找得到。

反過來說，同一行 `(import ./9-1-lib/greet)` 如果複製到別的資料夾的檔案裡，就會找不到，因為那支檔旁邊沒有 `9-1-lib/`。

### 沒有 ./ 的裸名字：走系統模組路徑

```janet
(import spork/path)
(print (path/join "a" "b"))   # 印出：a/b
```

`spork/path` 前面沒有 `./` 或 `../`，Janet 就不會去你旁邊找，而是去「系統模組路徑」找。這個路徑存在 `(dyn :syspath)`，`jpm install` 裝的套件都放那裡。在這台機器上它是：

```text
syspath：/home/lorkhan/.local/lib/janet
```

所以寫自己的檔一定要加 `./` 或 `../`。忘了加，Janet 會跑去系統模組路徑找，當然找不到：

```text
could not find module greet:
    /home/lorkhan/.local/lib/janet/greet.jimage
    /home/lorkhan/.local/lib/janet/greet.janet
    ...
```

錯誤訊息會列出它試過的每個位置。看到清單裡全是 syspath 底下的路徑，就知道是少了 `./`。

### 不用寫 .janet

`import` 後面寫的是模組名，不是檔名。你寫 `./9-1-lib/greet`，Janet 自己會補上 `.janet`（也會試 `.jimage`、`.so` 這些其他格式）。在 Janet 1.41.2 實測，多寫 `.janet` 也載得到，但慣例是不寫，別人的程式裡你看到的都是不帶副檔名的寫法。

續篇：[9-1b · import 的規則與坑](9-1b-import-的規則與坑.md)
