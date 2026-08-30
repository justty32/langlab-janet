# 08 · 巨集 macro

巨集在**編譯期**把程式碼轉成別的程式碼。因為 Janet 的程式就是資料（tuple / array），巨集其實
就是「吃 AST、吐 AST」的函式。

## 四個符號先記住

| 符號 | 名稱 | 作用 |
|------|------|------|
| `~` | quasiquote | 引用一段程式（不求值），但允許裡面挖洞 |
| `,` | unquote | 在 `~` 裡「挖洞」：這裡的東西**要**求值後填進來 |
| `,;` | unquote-splice | 挖洞並**攤平**一個序列進來 |
| `'` | quote | 純引用，整段都不求值 |

### ⚠ `;` 是 splice，**不是註解**

從 Common Lisp 或 Scheme 過來的人會反射性地用 `;` 寫註解——**Janet 的註解是 `#`**。
寫成 `;` 不會被忽略，它是 splice 運算子：

```janet
(print "a")  ; (print "b")
# => compile error: splice can only be used in function parameters
#                   and data constructors, it has no effect here
```

錯誤訊息完全不會提到「你以為這是註解」。單獨的 `;xs` 是「把 `xs` 攤平到這個位置」，
所以 `(f ;args)` 就是「把 args 陣列攤成一個個參數傳給 f」——跟 `,;` 在 `~` 裡做的事一樣，
只是不在 quasiquote 裡就不需要那個逗號。

## 定義巨集

```janet
(defmacro my-when [c & body]
  ~(if ,c (do ,;body)))            # 展開成 (if c (do body...))

(my-when true (print "hi"))        # => 印 hi
```

拆解 `~(if ,c (do ,;body))`：
- `~(...)` 我要生一段 `(if ...)` 程式碼。
- `,c` 把傳進來的條件 AST 填進去。
- `,;body` 把 `body`（一串運算式）攤平塞進 `(do ...)`。

```janet
(defmacro unless2 [c & body] ~(if ,c nil (do ,;body)))
(unless2 false (print "run"))      # => 印 run
```

## 看巨集展開成什麼（除錯必備）

```janet
(macex1 '(my-when x (foo) (bar)))
# => (if x (do (foo) (bar)))       # macex1 展開「一層」
(macex  '(my-when x (foo)))        # 展開到底（巢狀巨集都展開）
```

寫巨集卡住時，第一件事就是 `macex1` 看它到底生出什麼。

## 衛生：別讓臨時變數撞名

巨集裡如果自己 `let` 了一個變數，可能跟使用者的變數撞名。用 `with-syms` 生**保證不撞**的名字：

```janet
(defmacro swap [a b]
  (with-syms [tmp]                 # tmp 是一個 gensym，全域唯一
    ~(let [,tmp ,a] (set ,a ,b) (set ,b ,tmp))))

(var x 1) (var y 2)
(swap x y)                         # x=2 y=1
```

沒有 `with-syms` 而直接寫 `~(let [tmp ,a] ...)` 的話，若使用者剛好也有個叫 `tmp` 的變數就會出錯。
`with-syms` 是巨集正確性的標配。

## 什麼時候該用巨集

- **需要控制求值時機**：像 `my-when`、`unless`、`and`/`or` 短路——參數不能先被求值。
- **想造新語法 / DSL**：`for`、`loop`、`with`（自動清理資源）都是巨集。

反過來，**能用普通函式就別用巨集**——函式好測、好組合、能當值傳。巨集只在「函式做不到」
（要延遲求值、要看到未求值的程式結構）時才出手。

### ⚠ 「巨集不能當值傳」講得不夠精確

實測：巨集**本身就是一個 `:function`**（只是 meta 上多一個 `:macro true`），
所以 `(def f my-when)` 綁得起來、`(map my-when …)` 也叫得動。但——

```janet
(def f my-when)
(f true '(print 1))     # => (if true (do (print 1)))    ⚠ 拿到的是「程式碼」
```

**你拿到的是展開後的 AST，不是執行結果。**巨集只有寫在呼叫位置、由編譯器展開時
才有巨集的效果；傳出去之後它就只是一個「回傳程式碼」的普通函式。
所以結論不變（別把巨集當高階函式用），但理由是這個，不是「綁不起來」。

## 可跑範例

```sh
janet examples/macros.janet
```

每個巨集都把 `macex1` 的展開結果印出來，包括**不用 `with-syms` 會怎麼壞**——
展開成 `(let [tmp tmp] …)` 然後爆 `cannot set constant`，而錯誤訊息完全不會提到撞名。

下一步：[09-fiber.md](09-fiber.md)。
