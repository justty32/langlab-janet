# 43c · 從 C 過來：函式、模組、main 與標準 IO

[← 43b 控制流與位元](43b-從-C-控制流與位元.md)｜[43 入口](43-從-C-C++-過來.md)

## 可變參數：`...` → `& rest`

C 的 `va_list` 一整套，Janet 一個 `&`。剩下的參數收成 tuple，`;` 把 tuple 攤回去當參數：

```janet
(defn sum [& xs] (+ ;xs))
(sum 1 2 3)      # => 6
(sum)            # => 0      (+) 沒參數是 0
(+ ;[1 2 3])     # => 6      ; 就是 C 沒有的「把陣列攤開當參數」
```

## 預設參數：`&opt` ＋ `default`

C 沒有；C++ 的 `void f(int a = 3)` 對到：

```janet
(defn greet [name &opt greeting]
  (default greeting "hi")          # greeting 是 nil 才補
  (string greeting " " name))
(greet "a")        # => "hi a"
(greet "a" "yo")   # => "yo a"
```

⚠ 參數個數不對是**編譯錯**，`try` 攔不到——比 C 的 `-Wall` 還嚴。五種參數形式全在 [33](33-函式參數與閉包.md)。

## static 區域變數 → 閉包

C 的 `static int n = 0;` 放在函式裡，值跨呼叫保留。Janet 把 `var` 放在函式**外面一層**，讓函式抓住它：

```janet
(def next-id (do (var n 0) (fn [] (++ n))))
[(next-id) (next-id) (next-id)]   # => (1 2 3)
```

`n` 只有 `next-id` 看得到，跟 `static` 一樣藏起來；差別是每呼叫一次外層就多一份（[33](33-函式參數與閉包.md)）。

## header／模組 → import

沒有 `.h`／`.c` 之分，一個 `.janet` 檔就是一個模組，`(import ./util)` 之後用 `util/f` 叫。
路徑相對「寫這行的檔案」、`import` 只能放頂層、`:as` 改前綴，全在 [05e](05e-import-與模組路徑.md)。
不想公開的函式用 `defn-`，像 `static` 函式。

## main 與 argv

```janet
# m.janet
(print "頂層先跑")
(defn main [& args] (printf "main 收到 %j" args) (os/exit 3))
```

```sh
$ janet m.janet a b; echo "exit=$?"
頂層先跑
main 收到 ("m.janet" "a" "b")
exit=3
```

三件事跟 C 不一樣：**頂層程式碼先跑**（相當於全域初始化），`main` 是**跑完整支檔案後**被叫的
（[05b](05b-建立新專案.md)）；`args` 的第 0 格是檔名，跟 `argv[0]` 一樣；沒寫 `main` 也可以，
頂層程式碼就是程式。exit code 用 `(os/exit n)`，沒叫就是 0；沒攔到的 `error` 會讓 exit code 變 1。
`(dyn *args*)` 隨時拿得到 argv（[40](40-內建動態變數.md)）。

## stdin／stdout／stderr

| C | Janet | 備註 |
|---|-------|------|
| `printf("…\n")` | `(print …)`／`(printf "…" …)` | 都**自動加換行** |
| `printf("…")` 不換行 | `(prin …)`／`(prinf …)` | 少一個 t |
| `fprintf(stderr, …)` | `(eprint …)`／`(eprintf …)` | e 開頭 |
| `fputs(s, stderr)` | `(file/write stderr s)` | 不加換行 |
| `fgets(buf, n, stdin)` | `(getline)` 或 `(file/read stdin :line)` | ⚠ 回傳**含換行**的 buffer，EOF 給 `nil` |
| `fflush(stdout)` | `(flush)` | 見下 |

```sh
$ printf 'hello\n' | janet -e '(pp (getline "> ")) (pp (file/read stdin :line))'
> @"hello\n"
nil
```

`(string/trimr (getline))` 把換行去掉。`getline` 給的是 buffer 不是 string，要當 key 或比較先 `(string …)`。

⚠ stdout 是有緩衝的：重導向到檔案或管線時，`stderr` 會**先於**前面印的 stdout 出現。
實測 `(print "a") (eprint "b")` 接 `| cat` 印出 `b` 再 `a`；中間加 `(flush)` 才照順序。跟 C 一樣的行為，只是提醒一下。

## assert

```janet
(assert (= 1 2) "1 應該等於 2")   # 錯：1 應該等於 2
(assert false)                     # 錯：assert failure in false   （沒訊息時印運算式）
(assert 42)                        # => 42     成立時回那個值
```

沒有 `NDEBUG`，`assert` 永遠有效。錯誤處理的整套（`error`／`try`／`protect`）見 [20](20-錯誤處理與資源管理.md)。

## sizeof／型別查詢

沒有 `sizeof`。你在 C 裡問 `sizeof` 通常是為了兩件事，Janet 分別對到：

```janet
(length @[1 2 3])   # => 3      元素個數（array／tuple／字串／table 都吃）
(ffi/size :int)     # => 4      真的要 C 型別大小才用 ffi（10b）
(type 1)            # => :number
(type "a")          # => :string
(type @[])          # => :array
(type nil)          # => :nil
(number? 1)         # => true   每個型別都有對應的 ? 判斷函式
```

19 種 `type` 回傳值全表在 [38](38-型別全表.md)。字串轉數字 `(scan-number "12")` → `12`，失敗給 `nil` 不報錯；
數字轉字串 `(string 12)` → `"12"`。

## 可跑範例

```sh
janet examples/compare-c.janet
```

下一步：[44 從 Lua 過來](44-從-Lua-過來.md)、[45 從 Go 過來](45-從-Go-過來.md)，
或回 [01d](01d-提早離開-return-break-continue.md) 看 return／break／continue。
