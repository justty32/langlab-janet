# htmlgen／temple ・ 產生 HTML／模板引擎

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/htmlgen` 把巢狀 Janet 資料結構（array／tuple／table）轉成 HTML 字串。`spork/temple` 是**模板引擎**——把一段含特殊分隔符的字串編譯成函式，呼叫時代入變數渲染出結果（類似 Python 的 Jinja、JS 的 EJS）。全部範例皆以 `janet -e` 實測於 Janet 1.41.2、spork（`~/.local/lib/janet/spork/`）。

## htmlgen（4）

| 函式 | 簽名 | 說明 |
|---|---|---|
| `escape` | `(escape x)` | 把 `x`（會先 `string` 轉字串）裡的 `& " < > '` 換成 HTML 實體 |
| `html` | `(html data &opt buf)` | 把資料樹渲染成 HTML，寫進 `buf`（沒給就新開一個 buffer），回傳該 buffer |
| `raw` | `(raw text)` | 包一層，讓 `text` 原樣輸出、不被 `escape` |
| `doctype-html` | 值（非函式呼叫） | `<!DOCTYPE html>`，其實是 `(raw "<!DOCTYPE html>")` |

**資料樹規則**：`[:tag {"attr" "val"} 子節點...]`（tuple 第一格是標籤，第二格若是字典就當屬性）；array 展開成一串兄弟節點；字串／數字／布林值會被 `escape`；`nil` 印空字串；函式節點會被呼叫 `(f buf)`（`raw` 就是這樣做的）。

### 實測

```
(html [:ul {"class" "menu"} [:li "a"] [:li "b"]])
# => @"<ul class=\"menu\"><li>a</li><li>b</li></ul>"

(html [:img {:src "x.png"}])          # => @"<img src=\"x.png\"/>"   （自閉合標籤自動判斷）
(escape "<a href=\"x\">&'")            # => "&lt;a href=&quot;x&quot;&gt;&amp;&#39;"
(html doctype-html)                    # => @"<!DOCTYPE html>"
(html (raw "<b>x</b>"))                # => @"<b>x</b>"（不逃逸）
(html 42)                              # => @"42"
```

## temple（4）

`create`／`compile` 把字串編成渲染函式；`add-loader` 讓你能直接 `import` `.temple` 檔當模組。

| 函式 | 簽名 | 說明 |
|---|---|---|
| `compile` | `(compile str)` | 編譯字串，回傳一個吃 `&keys` 參數、回傳渲染結果字串的函式（最常用） |
| `create` | `(create source &opt where)` | 較底層版本：回傳一個吃**一個** `args` 字典參數的函式；`where` 只影響除錯訊息 |
| `add-loader` | `(add-loader)` | 把 `.temple` 檔登記進 `module/loaders`，之後可以 `(import "path/to/file")`（不含副檔名） |
| `base-env` | table | 模板內建的求值環境（含 `escape` 等），一般不用直接碰 |

### 模板語法（四種分隔符）

| 分隔符 | 作用 |
|---|---|
| `{{ 運算式 }}` | 求值後 **escape** 再插入輸出（安全預設） |
| `{- 運算式 -}` | 求值後**不 escape**直接插入（自己保證安全） |
| `{% 程式碼 %}` | 執行任意 Janet 程式碼（不插入回傳值），拿來寫迴圈／條件 |
| `{$ 程式碼 $}` | **編譯期**執行（例如 import），不是每次渲染都跑 |

模板函式體內部只有一個隱含參數 `args`（一個字典），沒有自動把 keys 拆成同名變數，所以要用 `(get args :key)` 取值。

### 實測：`compile`

```
(import spork/temple)
(def f (temple/compile "Hi {{ (get args :name) }}, items: {% (each x (get args :items) (prin x ",")) %}"))
(f :name "Bob" :items @[1 2 3])
# => "Hi Bob, items: 1,2,3,"
```

### 實測：`create`（回傳只吃一個字典參數的函式）

```
(import spork/temple)
(def tmpl (temple/create "Hello {{ (get args :name) }}!"))
(tmpl {:name "World"})
# 直接印到標準輸出：Hello World!  （create 產生的函式預設印到 (dyn :out)，回傳值另計）
```

### 實測：`add-loader` ＋ 把 `.temple` 當模組匯入

檔案 `hello.temple`：
```
Hello {{ (get args :name) }}!
```

```
(import spork/temple)
(temple/add-loader)
(import "./hello" :as tpl)      # 檔名不含 .temple
(tpl/render :name "World")       # => 印出 "Hello World!"（&keys 版本）
(tpl/render-dict {:name "Dict-World"})  # 同上，但吃字典
(tpl/capture :name "Captured")   # 不印，回傳渲染結果的 buffer
```
`.temple` 模組會提供 4 個綁定：`render`（&keys，直接印）、`render-dict`（字典版）、`capture`（&keys，回傳 buffer）、`capture-dict`（字典版，回傳 buffer）——這 4 個不算在 temple 自己的 4 個綁定內，是**每個 `.temple` 檔案**被 import 後才會有的。
