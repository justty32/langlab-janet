# 12 · env：環境表、動態變數、OS 環境變數

「env」在 Janet 語境裡有**兩個完全不同的東西**，先分清楚再往下讀：

| 講的是 | 是什麼 | 入口 |
|--------|--------|------|
| **環境表**（environment table） | Janet 自己的「名字 → 綁定」表，`def` 定義的東西住在這 | `(curenv)`、`make-env`、`fiber/setenv` |
| **動態變數**（dynamic bindings） | 執行期可覆寫的設定值，像 `(dyn :args)` | `dyn` / `setdyn` / `with-dyns` |
| **OS 環境變數** | shell 那個 `$PATH`、`$HOME` | `os/getenv` / `os/setenv` / `os/environ` |

前兩者其實是**同一張表**（見下一節），第三個是作業系統的東西，完全無關。

---

## 一、環境表就是一張普通 table

```janet
(pp (type (curenv)))                       # => :table
(pp (= (curenv) (fiber/getenv (fiber/current))))  # => true
```

`(curenv)` 拿到的就是**當前 fiber 的環境表**。它的 key 分兩種：

- **symbol key** → `def` / `defn` / `var` 定義的綁定
- **keyword key** → 動態變數（`setdyn` 寫的那些）

```janet
(def x 42)
(setdyn :myk 1)
(pp (get (curenv) 'x))      # => @{:source-map ("f.janet" 1 1) :value 42}
(pp (get (curenv) :myk))    # => 1
```

所以「環境表」和「動態變數」不是兩套機制，是同一張表的兩種 key。

### 一個綁定裡面有什麼

`(get env 'name)` 回傳的**不是值本身**，是一張描述綁定的 table：

```janet
(def x 42)          # => @{:value 42 :source-map (…)}
(var v 1)           # => @{:ref @[1] :source-map (…)}          ★ var 沒有 :value
(defn f "說明" [a] a) # => @{:value <function f> :doc "(f a)\n\n說明" :source-map (…)}
(defmacro mm [] 1)  # => @{:value <function mm> :macro true :doc (…) :source-map (…)}
(def- hidden 7)     # => @{:value 7 :private true :source-map (…)}
```

| 欄位 | 意思 |
|------|------|
| `:value` | 綁定的值（`def` 類） |
| `:ref` | `var` 專用：值裝在一個長度 1 的 array 裡，所以能改 |
| `:macro` | 這是巨集，不是函式 |
| `:doc` | docstring（`(doc name)` 印的就是它） |
| `:private` | `def-` / `defn-` 定義的，不會被 `import` 帶出去 |
| `:source-map` | `(檔名 行 欄)` |

取實際的值：`((get env 'x) :value)`；`var` 要 `(first ((get env 'v) :ref))`。

---

## 二、列出 env 裡的所有東西（常用的自省）

```janet
(all-bindings)                 # 當前 env 的所有 symbol（含繼承來的 core，700 多個）
(all-bindings (curenv) true)   # ★ local=true：只列「這張表自己有的」，不含 prototype 繼承
(all-dynamics)                 # 所有動態變數 keyword
(all-dynamics (curenv) true)   # 同理，只列本層
```

`all-bindings` 回傳的是**array of symbol**（不是 table，別對它 `keys`）。

```janet
(def e (dofile "m.janet"))
(pp (sort (all-bindings e true)))   # 列出某個「指定 env」定義了什麼
```

想自己動手篩，直接把 env 當 table 走：

```janet
(sort (filter symbol? (keys (curenv))))     # 本層定義的名字（keyword 那些會被濾掉）
(filter keyword? (keys (curenv)))           # 本層的動態變數
```

### 查某個 symbol 是什麼型別

三層問題，三個答案：

```janet
(type x)                            # 值的型別 => :number / :function / :table …
(type ((get (curenv) 'f) :value))   # 用名字（symbol）查值的型別 => :function
(get (curenv) 'mm)                  # 看綁定 meta：有 :macro true 就是巨集
(doc x)                             # 人看的：型別 + 定義位置 + docstring
```

判斷用的謂詞：`function?` `cfunction?` `keyword?` `symbol?` `table?` `struct?`
`array?` `tuple?` `buffer?` `string?` `bytes?`（string/buffer/keyword/symbol 都算）
`indexed?`（array/tuple）`dictionary?`（table/struct）`callable?`。

```janet
(defn kind [env sym]
  (def b (get env sym))
  (cond
    (nil? b)      :未定義
    (b :macro)    :macro
    (b :ref)      :var
    (type (b :value))))
(kind (curenv) 'map)   # => :cfunction
```

`(doc-of value)` 反過來：拿一個**值**去所有已載入模組裡找它叫什麼、印它的文件。

---

## 三、切換 env

### 3-1 `make-env`：開一張乾淨的新表

```janet
(def e (make-env))       # 繼承 core 的綁定，但新定義不會污染父層
```

`(make-env &opt parent)`：parent 預設是 `root-env`（核心綁定），用 prototype 繼承。

### 3-2 在指定 env 裡求值：fiber + `fiber/setenv`

`eval` / `eval-string` 永遠在**當前 fiber 的 env** 求值。要換一張表，就開個 fiber 換掉它的 env：

```janet
(def e (make-env))
(def f (fiber/new (fn [] (eval-string "(def secret 7) secret"))))
(fiber/setenv f e)
(resume f)                     # => 7
(pp (get e 'secret))           # => @{:value 7 …}   定義進了 e
(pp (get (curenv) 'secret))    # => nil             主 env 沒被污染
```

> **★ 大坑**：`fiber/new` 造出來的 fiber，**env 預設是 `nil`**，不是繼承父層。
> 所以 fiber 裡 `(dyn :任何東西)` 一律拿到 `nil`，直到你 `fiber/setenv` 給它一張表
> （或它自己 `setdyn` 時才會現生一張）。
>
> ```janet
> (setdyn :top "main")
> (def f (fiber/new (fn [] (pp (dyn :top)))))
> (resume f)                                  # => nil    ← 看不到外面
> (def g (fiber/new (fn [] (pp (dyn :top)))))
> (fiber/setenv g (curenv)) (resume g)        # => "main" ← 共用同一張表
> ```
>
> `ev/spawn` 不一樣，它**會**繼承當前 env：`(setdyn :k 1) (ev/spawn (pp (dyn :k)))` → `1`。

`fiber/setenv` 給的是**同一張表的參考**：fiber 內 `setdyn` 會寫回外面。要隔離就給
`(make-env (curenv))` 之類的子表。

### 3-3 `dofile` / `run-context`：跑一支檔案到指定 env

```janet
(def e (dofile "m.janet"))          # 回傳該檔跑完後的 env
(pp (get e 'secret))
(pp ((get e 'hi) :value))           # 取出裡面的函式

(dofile "m.janet" :env my-env)      # 指定要跑進哪張表
```

`run-context` 是底層版（REPL、`dofile`、`-e` 都走它），可換 `:env` `:chunks`
`:evaluator` `:on-compile-error` 等等，要自製 REPL / 沙箱時才用得到。

### 3-4 把一張 env 併進另一張

```janet
(def m (dofile "m.janet"))
(merge-module (curenv) m "mm-")     # 等於手工版的 import
(mm-hi)                             # => "hi from m"
```

`(merge-module target source &opt prefix export only)`——`only` 給 tuple 可只挑幾個名字。

### 3-5 `import` 的 env 選項

```janet
(import spork/json)                 # 綁成 json/encode …
(import spork/json :as J)           # J/encode
(import spork/json :prefix "js-")   # js-encode
(import spork/json :export true)    # 連帶再被別人 import 時也帶出去
(import ./janet-lab/init :as lab)   # 相對路徑以「啟動 janet 的目錄」為準
```

模組系統的兩張表：

```janet
module/cache      # 已載入的模組：路徑 → env（同一個模組只會跑一次）
module/paths      # 找模組的搜尋規則
(dyn :syspath)    # 全域模組根目錄 => "~/.local/lib/janet"
```

`(require "x")` = 載入並回傳 env、不做綁定；`import` = `require` + `merge-module`。

---

## 四、動態變數 dyn / setdyn / with-dyns

```janet
(setdyn :myk 1)          # 寫
(dyn :myk)               # 讀 => 1
(dyn :nope :fallback)    # 第二參數 = 預設值
(with-dyns [:myk 9]      # ★ 有作用域的覆寫，離開自動還原
  (dyn :myk))            # => 9
```

自己的專案要用動態變數，宣告一下比較好查：

```janet
(defdyn *verbose* "要不要囉唆")   # *verbose* 這個 symbol 之後就等於 :verbose
(setdyn *verbose* true)
(dyn *verbose*)                   # => true
```

內建常用的（`(all-dynamics)` 可全列）：

| key | 內容 |
|-----|------|
| `:args` | 命令列參數陣列 |
| `:executable` | janet 執行檔路徑 |
| `:current-file` | 目前在跑的檔名 |
| `:source` | 錯誤訊息用的來源名 |
| `:syspath` | 模組根目錄 |
| `:out` / `:err` | 輸出去向（可換成 buffer 來攔截輸出） |
| `:pretty-format` | `pp` 用的格式字串 |

---

## 五、OS 環境變數（跟上面完全無關）

```janet
(os/getenv "HOME")                 # => "/home/lorkhan"
(os/getenv "NOPE" "預設值")         # 找不到時的預設
(os/setenv "MY_VAR" "abc")         # 設
(os/setenv "MY_VAR" nil)           # 傳 nil = 刪掉
(os/environ)                       # 全部，回傳 table
```

給子行程指定環境：

```janet
(os/execute ["sh" "-c" "echo $MY_VAR"] :p)                    # 預設：繼承父行程環境
(os/execute ["sh" "-c" "echo $MY_VAR"] :pe {"MY_VAR" "override"})
```

> **★ 坑**：第三個參數（環境 table）**只有加了 `:e` 旗標才生效**。寫成 `:p` 而不是 `:pe`，
> 那張 table 會被安靜忽略、子行程照樣繼承你的環境——不會報錯，只是沒作用。

`:e` 給的是**完整取代**，不是疊加；要疊加自己 `(merge (os/environ) {...})`。同一個
table 還能塞 `:in` `:out` `:err` 做重導向（見 [11](11-pipeline-signal.md)）。

### 影響 Janet 自己的環境變數

| 變數 / 旗標 | 作用 |
|------------|------|
| `JANET_PATH=…` | 換模組根目錄（`(dyn :syspath)`）。裝在非標準位置的模組靠這個找到 |
| `janet -m 路徑` | 同上，命令列版 |
| `JANET_PROFILE=…` | 啟動時先跑的 profile.janet；`janet -R` 停用 |
| `janet -l 模組` | 處理後面參數前先載入某模組 |

> **★ `JANET_PATH` 只吃「一個目錄」，不是 PATH 那種冒號清單。**
> 寫成 `JANET_PATH=/a:/b` 的話，Janet 會老老實實去找 `/a:/b/spork/argparse.so` 這種目錄，
> 然後噴 `could not find module`。要多個搜尋位置得改 `module/paths`，不是塞冒號。
> （這台機器的 shell 就設了冒號清單，所以在這個 shell 直接跑 `jpm test` 會 build fail；
> `env -u JANET_PATH jpm test` 就正常。）

> **★ `-l` 的實際行為**：它只是把模組 `require` 進 `module/cache`（跑過一遍、快取起來），
> **不會幫你建綁定**。`janet -l spork/json -e '(json/encode …)'` 會噴 unknown symbol——
> 還是得在程式裡 `(import spork/json)`。

---

## 速查

| 想幹嘛 | 怎麼寫 |
|--------|--------|
| 拿當前環境表 | `(curenv)` |
| 列所有名字 | `(all-bindings)` / 只本層 `(all-bindings env true)` |
| 列所有動態變數 | `(all-dynamics)` |
| 看某綁定的 meta | `(get (curenv) 'name)` |
| 取某綁定的值 | `((get env 'name) :value)`（var 用 `:ref`） |
| 某 symbol 是什麼 | `(type ((get env 'name) :value))`、`(doc name)` |
| 開新環境 | `(make-env)` |
| 在別的 env 求值 | `fiber/new` + `(fiber/setenv f e)` + `resume` |
| 跑檔案拿它的 env | `(dofile "x.janet")` |
| 併別的 env 進來 | `(merge-module (curenv) e "字首")` |
| 讀 / 寫 OS 環境變數 | `(os/getenv "K")` / `(os/setenv "K" "V")` |
| 給子行程換環境 | `(os/execute args :pe env-table)`（別漏 `e`） |

完整可跑範例：[`examples/env-introspect.janet`](../examples/env-introspect.janet)。

下一步：[13-symbol-keyword-字串.md](13-symbol-keyword-字串.md)。
