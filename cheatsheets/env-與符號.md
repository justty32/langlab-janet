# env / 符號速查

環境表・動態變數・symbol↔字串・巨集・自省（Janet 1.41.2 實測）

## env 環境

`(curenv)` 就是一張 table：**symbol key = 綁定**，**keyword key = 動態變數**。

### 看 / 列

```janet
(all-bindings)              # 所有名字（array of symbol）
(all-bindings env true)     # ★ local：不含繼承的 core
(all-dynamics)              # 所有動態變數
(get (curenv) 'x)          ;=> @{:value 42 :source-map …}
(type ((get env 'f) :value)) ;=> :function 某 symbol 是啥
```

| 綁定欄位 | 意思 |
|---|---|
| `:value` | 值（def 類） |
| `:ref` | var 專用，值在 `@[v]` 裡 |
| `:macro` / `:private` / `:doc` | 是巨集 / def- / docstring |

### 切換 env

```janet
(def e (make-env))          # 新表，繼承 core
(def f (fiber/new |(eval-string "(def s 7) s")))
(fiber/setenv f e) (resume f) ;=> 7，定義進 e
(dofile "m.janet")          # 回傳該檔的 env
(merge-module (curenv) e "m-") # 手工版 import
```

> ⚠ **坑**：`fiber/new` 的 fiber **env 預設 nil**，裡面 `(dyn :k)` 一律 nil，要先 `fiber/setenv`。`ev/spawn` 則會繼承。

### 動態變數

```janet
(setdyn :k v) (dyn :k 預設)
(with-dyns [:k v] …)       # 有作用域，離開還原
(defdyn *verbose* "說明")   # *verbose* == :verbose
# 內建：:args :executable :current-file :syspath :out
```

### OS 環境變數（另一回事）

```janet
(os/getenv "HOME" "預設") (os/setenv "K" "V")
(os/setenv "K" nil)         # nil = 刪掉
(os/environ)
(os/execute args :pe {"K" "V"}) # ★ 少了 e 那張表會被忽略
```

## 符號 ↔ 字串

`:abc` 求值成自己（標籤）；`abc` 會被查表求值（名字）。

```janet
(keyword "some_symbol") ;=> :some_symbol
(symbol  "some_symbol") ;=> some_symbol
(string :some_symbol)  ;=> "some_symbol" ★ 沒冒號
(string/format "%q" :abc) ;=> ":abc" 要冒號用 %q
(symbol :abc) (keyword 'abc) # 互轉
(keyword "a-" 1 :b) ;=> :a-1b 多參數串接
```

> ⚠ **坑**：`(= "abc" :abc)` → **false**（跨型別永遠不等）。先 `(string x)` 統一再比。JSON key 是字串，所以 `decode` 要傳 `true`。

### 用執行期算出的名字

```janet
(t (keyword "a"))          # 取 table 的值
(eval (symbol "x"))        # 查綁定的值（會編譯，慎用）
((get (curenv) (symbol "x")) :value) # 較安全
```

`bytes?` 對 string／buffer／keyword／symbol 四種都真。細節見 `docs/13`。

## 巨集 macro

| 符號 | 意思 |
|---|---|
| `~` | quasiquote：引用程式、可挖洞 |
| `,` | unquote：挖洞，這裡求值 |
| `,;` | unquote-splice：挖洞並攤平 |
| `'` | quote：純引用不求值 |

```janet
(defmacro my-when [c & body]
  ~(if ,c (do ,;body)))
(macex1 '(my-when x (foo))) # 看展開！
;=> (if x (do (foo)))

# 衛生：用 with-syms 生不撞名的臨時變數
(defmacro swap [a b]
  (with-syms [t]
    ~(let [,t ,a] (set ,a ,b) (set ,b ,t))))
```

能用函式就別用巨集；只在「要延遲求值/看未求值結構」時出手。

## 自省 / 除錯

```janet
(disasm f :bytecode)  ;=> @[(mul 2 0 0) (ret 2)] 看 bytecode
(trace f) (f 4) (untrace f)
(macex1 '(when x y)) ;=> (if x (do y)) 展一層
(macex form)          # 展到底
(comptime …)          # 編譯期就算完，結果編成常數
(doc name) (doc-of value)
janet -d              # 內建除錯器
```

### 其他小工具

```janet
(int/s64 "9007199254740993") # 真 64-bit（一般 number 是 double）
(table/weak 4)              # 弱引用 table
(os/clock) (os/time)        # 高精度計時 / Unix 秒
```

`spork` 還有一整櫃：temple（模板）／http／netrepl（遠端 REPL）／rpc／schema／regex／infix／cjanet／fmt／cron／zip／utf8／rawterm…，見 `docs/16`。
