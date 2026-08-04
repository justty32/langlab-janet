# 12b · 切換 env

[← 12 env：環境表](12-env-環境與動態變數.md)｜下一篇：[12c 動態變數 dyn](12c-dyn.md)

「在另一張環境表裡跑程式」有好幾條路，差別在**要不要開新 fiber**、
**跑完之後那張表歸誰**。

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

