# 2-3 · 在 REPL 裡自助查

之後每一課都會碰到沒看過的函式。這課教你四招，讓你卡住時不用離開終端機翻文件，在 REPL 裡一句就查到「這東西是什麼、怎麼呼叫、定義在哪」。

## 這是什麼、為什麼

在 C 或 Python 裡，想知道一個函式怎麼用，多半要開瀏覽器或翻標頭檔。Janet 不一樣：每個函式的說明文字、型別、定義在哪支檔第幾行，都直接帶在函式身上，程式跑起來之後隨時能問。

REPL（1-1 開過的那個互動視窗）就是拿來問的地方。這課的四招是 `doc`、`doc` 給字串、`all-bindings`、`type`。學完之後，後面每課卡住先試這四招，多半不用翻書。

## 動手：doc，看說明

`(doc 名字)` 把某個名字的說明印出來。拿 `string/split` 試：

```janet
(doc string/split)
# 印出：
#     cfunction
#     src/core/string.c on line 439, column 1
#
#     (string/split delim str &opt start limit)
#
#     Splits a string `str` with delimiter `delim` and returns an array ...
```

這幾行怎麼讀。第一行 `cfunction` 是它的種類，意思是「用 C 寫的函式」（Janet 核心大多是 C 寫的）。第二行是定義位置，core 的東西會指向 Janet 的 C 原始碼；你自己寫的會指向你的檔案與行號。括號那行是呼叫方式：`delim` 與 `str` 一定要給，`&opt` 後面的 `start`、`limit` 可給可不給。最後是說明文字。

對自己寫的函式也一樣有效。定義函式時，把一段字串放在參數前面，那段字串叫 docstring（寫在函式定義裡的說明文字），就是給 `doc` 看的：

```janet
(defn hello "打招呼" [name] (string "hi " name))
(doc hello)
# 印出：
#     function
#     repl on line 1, column 1
#
#     (hello name)
#
#     打招呼
```

這次第一行是 `function`，表示是 Janet 寫的函式；第二行的 `repl on line 1` 是因為在 REPL 裡定義的，若寫在檔案裡就會是檔名與行號。

兩種查不到的情況也要認得。名字存在但沒寫 docstring（例如 `(def x 1)` 之後 `(doc x)`），會印 `no documentation found.`；名字根本不存在（`(doc nosuch)`），會印 `symbol nosuch not found.`，不會拋錯，只是提醒你。

## 動手：doc 給字串，用片段找名字

只記得名字的一部分怎麼辦？`doc` 給字串就變成搜尋：列出所有名字含那個片段的綁定（一個名字和它指的東西）。

```janet
(doc "string/spl")
# 印出：
#     Bindings:
#
#     string/split
#
#     Dynamics:
#
#     Use (doc sym) for more information on a binding.
```

別的 Lisp 常有一個叫 `apropos` 的指令做這件事，Janet 沒有（打了會說 `unknown symbol apropos`），這裡就是用 `doc` 給字串。`(doc)` 什麼都不給會列出全部 700 多個名字，太長，通常不這樣用。

## 動手：all-bindings，拿到名字清單

`(all-bindings)` 回傳一個 array，裡面是目前所有名字（symbol）。它是資料，所以可以拿來算、拿來篩：

```janet
(print (length (all-bindings)))
# 印出：702（數字隨版本變）
(pp (filter |(string/has-prefix? "string/sp" $) (all-bindings)))
# 印出：@[string/split]
```

第二行的 `|(...)` 等於一個小函式，`$` 是它的參數，`filter` 把每個名字丟進去、留下回傳真的。這寫法 6-2 細講，現在照抄就好。

## 動手：type，看型別

拿到一個值不知道是什麼，`(type x)` 回傳一個 keyword 告訴你。1-3 講過的幾種值都認得：

```janet
(type 1)           # => :number
(type "a")         # => :string
(type :a)          # => :keyword
(type 'a)          # => :symbol
(type nil)         # => :nil
(type true)        # => :boolean
(type @[1])        # => :array
(type [1])         # => :tuple
(type @{})         # => :table
(type {})          # => :struct
(type @"b")        # => :buffer
(type (fn [] 1))   # => :function
(type print)       # => :cfunction
```

`'a` 前面那個引號是叫 Janet「別去求值，把 a 當名字本身」。容器那四種 3-1 會講，這裡先看到它們各有各的型別就好。

## 動手：看定義在哪

`(doc hello)` 已經印了檔名行號。想拿到程式能用的資料，用 `(curenv)`，它回傳目前這張「名字 → 東西」的表，再用 `get` 拿某個名字，會得到一張描述綁定的 table：

```janet
(defn hello "打招呼" [name] (string "hi " name))
(pp (get (curenv) 'hello))
# 印出：@{:doc "(hello name)\n\n\xE6\x89\x93\xE6\x8B\x9B\xE5\x91\xBC" :source-map ("repl" 1 1) :value <function hello>}
```

`:source-map` 是 `(檔名 行 欄)`，`:value` 是函式本身，`:doc` 是 docstring。docstring 裡的中文被印成 `\xE6…`，這是 2-2 講過的 `pp` 逃逸，不是壞掉。

## 動手：在 REPL 裡實際長這樣

```text
$ janet
Janet 1.41.2-0fea20c linux/x64/gcc - '(doc)' for help
repl:1:> (type print)
:cfunction
repl:2:> (doc nosuch)
symbol nosuch not found.
nil
```

每次求值 REPL 會印回傳值，`doc` 印完之後回傳 `nil`，所以多一行 `nil`。查外部模組的函式要先載入，例如 `(import spork/json)` 之後才能 `(doc json/encode)`，第 4、9 單元細講。

整理成一套卡住流程。不知道名字：`(doc "片段")`。知道名字：`(doc 名字)`。拿到一個值不知道是什麼：`(type x)` 加 `(pp x)`。

## 你會踩的坑

⚠ 你會以為 `print` 是函式，所以 `(function? print)` 是 true。其實是 false。因為 `print` 是 C 寫的，型別是 `:cfunction`，而 `function?` 只認 Janet 寫的 `:function`；要兩種都算，得寫 `(or (function? x) (cfunction? x))`。

```janet
(function? print)    # => false
(cfunction? print)   # => true
```

## 小練習

1. 用 `doc` 給字串找出所有名字含 `has-` 的函式，再用 `doc` 看其中一個怎麼呼叫。
2. 寫一個有 docstring 的函式 `double`（回傳兩倍），用 `(get (curenv) 'double)` 拿出它的 `:doc` 印出來。
3. 用 `all-bindings` 加 `filter` 數一數名字以 `os/` 開頭的有幾個。

答案在 [examples/course/2-3.janet](../examples/course/2-3.janet) 尾端。

## 想更深

- [docs/07 REPL 用法](../docs/07-repl.md)：多講了怎麼把模組與檔案載進 REPL、以及在編輯器裡接 REPL。
- [docs/12 env 環境與動態變數](../docs/12-env-環境與動態變數.md)：多講了 `curenv` 那張表裡每個欄位的意思、var 與巨集長什麼樣。
- [docs/16 marshal 與自省](../docs/16-marshal-與自省.md)：多講了看 bytecode、追蹤呼叫、展開巨集這些更深的自省工具。

下一課：[3-1 · 四個容器](3-1-四個容器.md)
