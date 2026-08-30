# 31 · spork 產生 HTML

spork 給你**兩條**產 HTML 的路，取捨很清楚：

| | 你寫的是 | 適合 |
|---|----------|------|
| **`htmlgen`** | **Janet 資料結構**：`[:p {:class "x"} "hi"]` | HTML 是**程式算出來的**（表格、清單、報表） |
| **`temple`** | **模板字串**，HTML 為主、程式碼插在中間 | HTML 是**寫死的版面**，只有幾個洞要填 |

兩者**預設都會自動跳脫**，這是它們最重要的共同點——先講這個。

## ⚠ 先講安全：自動跳脫，除非你叫它別跳

把使用者輸入直接拼進 HTML 是經典的 XSS 漏洞。這兩個模組都幫你擋掉了：

```janet
(htmlgen/html [:p "<script>alert(1)</script>"])
# => <p>&lt;script&gt;alert(1)&lt;/script&gt;</p>     ← 變成純文字，不會執行
```

⚠ **危險的是你主動關掉跳脫的時候**：`htmlgen` 的 `raw`、`temple` 的 `{- -}`。
這兩個是「我保證這段是安全的 HTML」的宣告——**只用在你自己產生的字串上，
絕對不要餵使用者輸入進去**。

## 一、htmlgen：用資料結構寫 HTML

規則就一條：**`[標籤 {屬性} 子元素...]`**。

```janet
(import spork/htmlgen)

(htmlgen/html [:ul [:li "a"] [:li "b"]])
# => <ul><li>a</li><li>b</li></ul>

(htmlgen/html [:a {:href "/x" :class "btn"} "點我"])
# => <a class="btn" href="/x">點我</a>

(htmlgen/html [:br])          # => @"<br/>"      自閉合標籤自動處理
(htmlgen/html [:p 42])        # => @"<p>42</p>"  數字自動轉字串
(htmlgen/html [:p nil "a"])   # => @"<p>a</p>"   nil 子元素直接跳過
```

⚠ **回傳的是 `buffer` 不是 `string`**（那些 `@"…"` 就是這個意思）。要比較、當字典的鍵、
或塞進 JSON 之前記得 `(string …)`——buffer 跟 string 內容一樣也不相等（[13](13-symbol-keyword-字串.md)）。

因為標籤就是普通的 Janet 資料，**你可以用 `map`／`seq` 生出來**——這才是它的價值：

```janet
(htmlgen/html [:ul ;(map |[:li $] ["a" "b" "c"])])
# => <ul><li>a</li><li>b</li><li>c</li></ul>
```

### ⚠ 三個實測出來的細節

**一、頂層只能放一個元素。**

```janet
(htmlgen/html [[:p "一"] [:p "二"]])   # ✘ error: bad slot #2, expected string... got <tuple>
(htmlgen/html [:div [:p "一"] [:p "二"]])  # ✓ 包一層就好
```

錯誤訊息（`bad slot #2, expected string...`）完全看不出「你頂層放了兩個元素」——它把第一個元素當成標籤名了。

**二、第二個參數是輸出 buffer**，要接在既有內容後面時用它：

```janet
(def b @"")
(htmlgen/html [:p "x"] b)     # 附加到 b，同時也回傳 b
```

**三、`doctype-html` 不是字串，是函式。**

`raw` 回的其實是 `(fn [buf] (buffer/push buf text))`，而 `doctype-html` 就是
`(raw "<!DOCTYPE html>")`——所以 `(buffer/push b htmlgen/doctype-html)` 會爆。
正確用法是**把它當函式呼叫**：

```janet
(def b @"")
(htmlgen/doctype-html b)                     # 它自己就是 (fn [buf] ...)
(htmlgen/html [:html [:body [:h1 "標題"]]] b)
(print b)
# => <!DOCTYPE html><html><body><h1>標題</h1></body></html>
```

## 二、temple：模板

版面固定、只有幾個洞要填時，用模板比堆資料結構好讀。

```janet
(import spork/temple)

(def 樣板 (temple/create "你好 {{ (args :name) }}！"))
```

`create` 把模板字串**編譯成一個函式**。它**不回傳字串**，而是**印到 `(dyn :out)`**——
所以要拿到結果得自己接：

```janet
(defn render [f data]
  (def buf @"")
  (with-dyns [:out buf] (f data))
  (string buf))

(render 樣板 {:name "Alice"})   # => "你好 Alice！"
```

傳進去的資料在模板裡叫 **`args`**。

### 四種標記

| 寫法 | 意思 | 實測 |
|------|------|------|
| `{{ 運算式 }}` | 求值、**跳脫**後插入 | `{{ (args :x) }}` 餵 `"<script>"` → `&lt;script&gt;` |
| `{- 運算式 -}` | 求值、**不跳脫**插入 | 餵 `"<b>粗</b>"` → `<b>粗</b>` |
| `{% 程式碼 %}` | 只執行、不輸出 | 迴圈與條件用這個 |
| `{$ 程式碼 $}` | **編譯期**執行 | 放 `import` 之類的東西 |

⚠ 迴圈與條件的寫法會嚇到人——**一個 form 是跨兩個 `{% %}` 寫的**，
中間夾的 HTML 就是 body：

```janet
"{% (each i (args :xs) %}<li>{{ i }}</li>{% ) %}"
# 餵 {:xs ["a" "b"]} => <li>a</li><li>b</li>

"{% (if (args :ok) %}好{% ) %}"
# 餵 {:ok true} => 好
```

看那個孤零零的 `{% ) %}`——它就是「把上面那個括號收起來」。第一次看到會以為寫壞了，
但這正是 temple 的設計：`{% %}` 裡的東西**原樣接進產生的程式碼**，所以括號自己配對。

## 選哪個

- **HTML 結構是算出來的**（迴圈生表格、依資料決定要不要出現某區塊）→ **`htmlgen`**。
  資料結構可以 `map`、可以組合、可以寫成函式回傳，比字串好操作太多。
- **版面是設計好的、只有幾個洞**（一封信、一頁報告）→ **`temple`**，
  因為模板檔看起來就是 HTML，改版面的人不必懂 Janet。
- **要產 Markdown 風格的文件**而不是 HTML → 看 `spork/mdz`
  （筆記在 [`reference/spork/mdz-文件產生.md`](../reference/spork/mdz-文件產生.md)）。

> 本 repo 的 [`html/`](../html/index.html) 速查表是**手寫**的靜態 HTML，沒有用這兩個——
> 因為它只有六頁、而且要精細控制排版。有幾十頁要生才划算。

## 可跑範例

`janet examples/spork-tour.janet`（htmlgen 有一段）。清單見
[`reference/spork/htmlgen-temple-產生-html.md`](../reference/spork/htmlgen-temple-產生-html.md)，
完整 API 查[官方 repo](https://github.com/janet-lang/spork)。

下一步：回 [docs 目錄](README.md) 挑下一篇。
