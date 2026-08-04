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

## 這一篇拆成三份

| 檔 | 內容 |
|----|------|
| **本篇** | 環境表就是一張 table、一個綁定裡有什麼、列出所有綁定、查 symbol 型別 |
| [12b · 切換 env](12b-切換-env.md) | `make-env`、`fiber/setenv`、`dofile`／`run-context`、`merge-module`、`import` 的 env 選項 |
| [12c · 動態變數 dyn](12c-dyn.md) | **`dyn` 到底是什麼**、`with-dyns`、per-fiber、跟「全域變數」的差別 |
| [12d · OS 環境變數](12d-os-環境變數.md) | `os/getenv`、給子行程指定環境、`JANET_PATH`、速查 |

可跑的範例在 [`../examples/env-introspect.janet`](../examples/env-introspect.janet)。
