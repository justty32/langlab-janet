# 10c · FFI：字串回傳與地雷合輯

[← 10b 型別、指標與記憶體](10b-ffi-型別與指標.md)｜下一篇：[10d native 模組與嵌入](10d-native-與嵌入.md)

### `char*` 回傳值怎麼變成 Janet 字串

這是最反直覺的一段。回傳型別寫 `:string` 時 Janet 會**自動**轉：

```janet
(def getenv (ffi/lookup libc "getenv"))
(ffi/call getenv (ffi/signature :default :string :string) "HOME")   # => "/home/lorkhan"
```

但若你拿到的是 `:ptr`（例如從 struct 裡讀出來的），**不能** `(ffi/read :string ptr)`——
`ffi/read` 會把 `ptr` 指到的地方**再當成一個 `char*` 來解**，八成 segfault。正解是把
指標本身寫進 buffer 再讀：

```janet
(def p (ffi/call getenv (ffi/signature :default :ptr :string) "HOME"))
(ffi/read :string (ffi/write :ptr p))       # ✓ => "/home/lorkhan"
```

或者知道長度時，用 `pointer-buffer` 直接把那段記憶體看成 buffer：

```janet
(def n (int/to-number
         (ffi/call (ffi/lookup libc "strlen") (ffi/signature :default :size :ptr) p)))
(string (ffi/pointer-buffer p n n 0))       # => "/home/lorkhan"
```

### ★ 指標與記憶體的地雷合輯

| 症狀 | 原因 / 正解 |
|------|------------|
| 回傳 `:string` 但程式 **segfault** | C 回了 **NULL**，`:string` 轉換不接受 NULL。改用 `:ptr` 回傳（NULL → `nil`），自己判斷後再轉字串 |
| `(ffi/read :string ptr)` 炸掉 | `ffi/read` 把 ptr 當「存著 char\* 的位址」。要 `(ffi/read :string (ffi/write :ptr ptr))` |
| `ffi/call` 直接 segfault，沒有錯誤訊息 | `(ffi/lookup lib "打錯的名字")` **回傳 `nil` 不報錯**，拿 nil 去 call 才炸。lookup 完先檢查 |
| `:size` 回來的值不能算術 | 是 `core/u64` / `core/s64` 抽象型別，要 `(int/to-number n)` |
| C 寫進 buffer 但 Janet 讀是空的 | 用了 `(buffer/new n)`（長度 0）。要 `(buffer/new-filled n)` |
| 傳 buffer 給 C 之後值變垃圾 | Janet buffer 一長大就 realloc、舊指標失效。C 端要長期持有的記憶體用 `ffi/malloc`，別給 Janet buffer |
| `ffi/malloc` 的記憶體漏光 | GC **不管** `ffi/malloc`，一定要自己 `ffi/free`；包一層 `defer` 比較保險 |
| 型別寫錯但沒 segfault | 參數型別對不上時 Janet 會先擋（`bad slot #N, expected number…`）；**大小 / 順序**寫錯它擋不住，那才是 segfault 的來源 |

### 回呼（callback）

`ffi/trampoline` 可以做出給 C 呼叫的函式指標，但**只支援一種簽名**：
`void f(void *ctx, void *userdata)`，其中 `userdata` 要放一個 Janet function，
真正的參數要從 `ctx` 用 `ffi/read` 挖。所以它只適合「C API 有 userdata 欄位」的那種
回呼；像 `qsort` 那種沒有 userdata 的接不上。要正經做回呼，寫 native 模組（下一節）
比硬凹 FFI 省事得多。

（另有 `ffi/jitfn`：把一段機器碼塞進可執行記憶體當函式指標用。除非你在寫 JIT，不會用到。）

