# mdz ・ mendoza 風格文件產生

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/mdz` 是 Calvin Rose 的靜態網站產生器 [mendoza](https://github.com/bakpakin/mendoza) 用的標記語法（不是一般 Markdown，是「Janet 程式碼＋文字」混寫的格式，設計來搭配 `spork/htmlgen` 產生 HTML）。全部範例皆以 `janet -e` 實測於 Janet 1.41.2。

## 語法規則（先看這個才看得懂範例）

一份 `.mdz` 原始碼分兩段，用單獨一行 `---` 分隔：

```
<front matter：一個會被求值成 table/struct 的 Janet 運算式>
---
<正文：標記語法>
```

正文裡：`# 標題` 到 `######` 是標題（`h1`～`h6`）；`- 項目` 開頭的連續行是無序清單；`1.` 開頭是有序清單；`@名字{內容}`、`@名字(參數)` 或 `@名字"字串"` 是呼叫一個 Janet 函式節點（例如 `@strong{粗體}`）；其餘文字是段落。

## API（32 個綁定）

### 剖析入口

| 函式 | 簽名 | 說明 |
|---|---|---|
| `markup` | `(markup source &opt env where)` | 剖析＋求值一份 mdz 原始碼，回傳一個環境（env），結果放在兩個動態變數裡 |
| `mdz-loader` | `(mdz-loader path &)` | 讓 `.mdz` 檔可以被當模組載入的 loader |
| `add-loader` | `(add-loader)` | 把 `.mdz` 登記進 `module/loaders`，之後可 `(import "path/to/file")` |
| `*front-matter*` | 動態變數（keyword） | 解析完後，front matter 的值存在 `(get env *front-matter*)` |
| `*markup-dom*` | 動態變數（keyword） | 解析完後，可餵給 `htmlgen/html` 的文件樹存在 `(get env *markup-dom*)` |

### 標籤產生函式（給 `@名字{...}` 呼叫，或直接呼叫）

| 函式 | 簽名 | 說明 |
|---|---|---|
| `div` `em` `li` `ol` `p` `pre` `strong` `sub` `sup` `tr` `td` `th` `u` `ul` | `(名字 content)` | 包成對應的 HTML 標籤，無屬性 |
| `tag` | `(tag name content)` | 通用版：`[name content]`，`name` 可自訂 |
| `hr` | `(hr)` | 水平線 `[:hr]` |
| `bigger` / `smaller` | `(bigger content)` / `(smaller content)` | 用 `<span style="font-size:...">` 放大／縮小字體（黃金比例） |
| `code` | `(code content)` | `<code class="mendoza-code">` |
| `codeblock` | `(codeblock lang &opt source)` | 程式碼區塊；只給一個參數時當作無語言標註的原始碼 |
| `anchor` | `(anchor name & content)` | 頁內錨點 `<a name="...">` |
| `link` | `(link url &opt content)` | 超連結，`content` 省略則顯示網址本身 |
| `section` | `(section name content)` | `<section name="...">`，常用來把不同段落內容分派到頁面模板的不同位置 |
| `blockquote` | `(blockquote content)` | 引言區塊 |
| `image` | `(image src alt)` | `<img>` |
| `center` | `(center content)` | 置中的 `<div>` |
| `html` | `(html source)` | 內嵌原始 HTML（等同 `htmlgen/raw`） |

## 實測：front matter 陷阱

**front matter 只取最後一個 top-level form 的值**（不是全部 form 合併），而且**開頭不能再多一組 `---`**（`---` 本身就是分隔符，不是「front matter 也要頭尾包起來」）：

```
(import spork/mdz)
(def env (mdz/markup "{:title \"Test\"}\n---\n# Hello\nSome @strong{bold} text.\n"))
(get env mdz/*front-matter*)   # => {:title "Test"}
```

## 實測：完整走一輪（剖析 → 產生 HTML）

```
(import spork/mdz)
(import spork/htmlgen)
(def env (mdz/markup "{:title \"Test\"}\n---\n# Hello\nSome @strong{bold} text.\n"))
(def dom (get env mdz/*markup-dom*))
(htmlgen/html [:html [:body dom]])
```
輸出（`h1` 的 `id` 屬性是自動從標題文字產生的）：
```
<html><body>
<h1 id="Hello">Hello</h1>
<p>Some <strong>bold</strong> text.
</p></body></html>
```

## 實測：清單

```
(mdz/markup "{}\n---\n- one\n- two\n- three\n")
# markup-dom => @["\n" (:ul (:li "one") (:li "two") (:li "three"))]
```
清單項目必須各自獨立成行、行首是 `-`／`數字.`；接在段落文字後面同段不會被認成清單。

## 實測：各標籤函式直接呼叫（不透過 mdz 語法）

```
(import spork/mdz) (import spork/htmlgen :as h)
(h/html (mdz/link "https://a.b" "click"))    # => "<a href=\"https://a.b\">click</a>"
(h/html (mdz/link "https://a.b"))             # => "<a href=\"https://a.b\">https://a.b</a>"（省略內容就顯示網址）
(h/html (mdz/image "x.png" "alt text"))       # => "<img alt=\"alt text\" src=\"x.png\"/>"
(h/html (mdz/codeblock "janet" "(+ 1 2)"))    # => "<pre class=\"mendoza-codeblock\"><code data-language=\"janet\">(+ 1 2)</code></pre>"
(h/html (mdz/hr))                              # => "<hr/>"
(h/html (mdz/bigger "big"))    # => "<span style=\"font-size:1.61803398875em;\">big</span>"
(h/html (mdz/center "c"))       # => "<div class=\"mendoza-center\">c</div>"
```

## 白話：跟一般 Markdown 差在哪

mdz／mendoza 不是給人手寫大量文章用的通用 Markdown，而是**內嵌 Janet 程式碼的標記**：`@tag{...}` 可以呼叫任何 Janet 函式（含你自訂的），front matter 本身就是一段可執行的 Janet 運算式（不只是 YAML 那種純資料）。適合拿來做「靜態網站產生器」這種需要在文件裡插程式邏輯的場景；一般寫筆記用標準 Markdown 反而更輕鬆。
