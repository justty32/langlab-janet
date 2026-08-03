# 16 · marshal、image 與自省

兩件 Janet 做得比多數語言徹底的事：**把活的東西序列化**，以及**在執行期看清楚自己**。

## marshal：連閉包和暫停中的 fiber 都存得下

```janet
(defn adder [n] (fn [x] (+ x n)))
(def bytes (marshal (adder 5)))     # closure 連捕獲的 n 一起 → 74 bytes
((unmarshal bytes) 10)              ;=> 15
```

不只資料，**函式本身**（bytecode + 捕獲的環境）都存得下來。更誇張的是 fiber：

```janet
(def f (fiber/new (fn [] (yield 1) (yield 2) (yield 3))))
(resume f)                                          ;=> 1
(def snap (marshal f (invert (env-lookup root-env))))
(def f2 (unmarshal snap (env-lookup root-env)))
[(resume f2) (resume f2)]                           ;=> (2 3)   從斷點續跑
```

第二個參數是**查找表**：告訴 marshal「這些東西不用存進去，還原時去環境裡撈」。存 fiber 或
會用到核心函式的閉包時必須給，否則整個 core 都會被塞進 bytes 裡（或直接失敗）。

- 存：`(invert (env-lookup 環境))`
- 讀：`(env-lookup 環境)`

### marshal vs JSON

| | JSON | marshal |
|---|------|---------|
| 人看得懂 / 可 diff | ✓ | ✗（二進位） |
| 跨語言 | ✓ | ✗（只有 Janet） |
| 存得下 keyword / tuple / struct | ✗ | ✓ |
| 存得下函式 / fiber | ✗ | ✓ |
| 大小 | 較大 | 較小 |
| 版本穩定 | ✓ | ✗ **換 Janet 版本可能讀不回來** |

結論：設定檔、要進 git、要給別的程式看 → JSON。快取、中繼檔、要保留型別 → marshal。
**別把 marshal 當長期儲存格式。**

可跑對照：[`snippets/json-and-marshal.janet`](../snippets/json-and-marshal.janet)。

### image：把整個環境存起來

`janet -c 原始碼 輸出` 就是把一整張 env marshal 成 image，`janet -i` 讀回來跑。
程式內對應 `make-image` / `load-image`：

```janet
(def img (make-image (make-env)))   # => buffer
(load-image img)                    # => env
```

`jpm build` 編獨立執行檔時，內部也是這一套。

## 自省：看清楚執行期的自己

### 看 bytecode

```janet
(defn sq [x] (* x x))
(disasm sq :bytecode)   ;=> @[(mul 2 0 0) (ret 2)]
(keys (disasm sq))      ;=> :arity :bytecode :constants :source :sourcemap :slotcount …
```

想知道某種寫法有沒有比較快，直接看指令數比猜有用。

### 追蹤呼叫

```janet
(trace sq)
(sq 4)          # 印出 trace (sq 4)
(untrace sq)
```

### 編譯期求值

```janet
(defn f [] (comptime (do (print "這行在編譯期就印了") 42)))
(f)   ;=> 42   執行期只是回傳一個常數
```

`comptime` 把括號裡的東西在**編譯那一刻**算完，結果當成字面常數編進去。查表、算常數、
讀死的設定檔都適合。

### 其他

```janet
(macex1 '(when x y))        # 展開一層巨集（除錯巨集的第一招）
(macex '(when x y))         # 展開到底
(int/s64 "9007199254740993") # 真 64 位元整數（一般 number 是 double，53 bits）
(table/weak 4)              # 弱引用 table，值被 GC 掉就自動消失
(os/clock) (os/time)        # 高精度計時 / Unix 秒
(gccollect) (gcsetinterval …)
```

環境自省（列出所有綁定、查某 symbol 是什麼）在 [12](12-env-環境與動態變數.md)。

## spork 裡還有一整櫃

`spork` 不只 json / argparse / sh / path。掃一眼知道有什麼，需要時才細看：

| 模組 | 幹嘛的 |
|------|--------|
| `spork/temple` | HTML 模板（`{$ … $}` 設定、`{{ … }}` 插值） |
| `spork/http` `spork/httpf` | HTTP client / 小型 server 框架 |
| `spork/netrepl` | 遠端 REPL（連進正在跑的行程改東西） |
| `spork/rpc` | 行程間呼叫 |
| `spork/schema` | 資料驗證：`(schema/predicate (props :name :string :age :number))` → 回傳一個 `(f 資料)` 判真假的函式。★ 是巨集，schema 直接寫、不要 quote；`schema/validator` 版本改成驗不過就丟例外 |
| `spork/regex` | 真 regex 編成 PEG |
| `spork/infix` | `(infix/$$ 1 + 2 * 3)` → 7，中綴運算 |
| `spork/cjanet` | 用 Janet DSL 產生 C 原始碼再編成 native 模組 |
| `spork/fmt` | 程式碼格式化器（`(fmt/format "(defn  f[x]…")`） |
| `spork/generators` | 惰性序列 |
| `spork/cron` `spork/date` | 排程字串 / 日期 |
| `spork/zip` `spork/base64` `spork/crc` `spork/utf8` | 壓縮 / 編碼 / 校驗 / UTF-8 |
| `spork/test` | 測試輔助 |
| `spork/tasker` `spork/services` | 工作佇列 / 服務管理 |
| `spork/rawterm` | 終端機原始模式（做 TUI 用） |
| `spork/tarray` | typed array（數值運算） |

裝在 `~/.local/lib/janet/spork/`，`ls` 一下就是完整清單。

---

回目錄：[docs/README.md](README.md)。
