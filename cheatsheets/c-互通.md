# C 互通速查

FFI・指標與記憶體・native 模組・把 Janet 嵌進 C（Janet 1.41.2 實測）

## 與 C 互通

| 方式 | 編 C? | 用途 |
|---|---|---|
| FFI | 不用 | 直呼現成 `.so` |
| native 模組 | jpm 編 | 用 C 寫 Janet 函式 |
| 嵌入 | 編 C | C 程式內跑 Janet |

### FFI（不編譯，直呼）

```janet
(def m (ffi/native "libm.so.6"))
(def sig (ffi/signature :default :double :double))
(ffi/call (ffi/lookup m "cos") sig 0.0) ;=> 1.0
# 少寫樣板版：
(ffi/context "libm.so.6")
(ffi/defbind pow :double [x :double y :double])
(pow 2 10) ;=> 1024
```

### 嵌入（C 裡跑 Janet）

```c
// C
janet_init();
JanetTable *e = janet_core_env(NULL);
janet_dostring(e, "(+ 2 3)", "m", &out);
```

連結：`-I~/.local/include/janet ~/.local/lib/libjanet.a -lm -ldl -lpthread -lrt -rdynamic`。細節見 `docs/10` 與 `examples/`。

## 10⁺ FFI 指標與記憶體

### 型別

```janet
# :void :bool :char :short :int :long :size :float :double :ptr :string
# :s8/:u8 :s16/:u16 :s32/:u32 :s64/:u64 :uchar :ushort :uint :ulong
(ffi/size :long) (ffi/align :long) # 永遠用問的，別猜
(ffi/struct :long :long)   # struct，padding 自動算
@[:char 4]                  # 陣列型別 char[4]（★ 要 @[] 不是 []）
```

### 記憶體 ↔ Janet 值

```janet
(ffi/write ts [7 8])          # 值 → buffer（原始位元組）
(ffi/read  ts buf 0)         # buffer → 值，第三參 = byte offset
(ffi/write :int 9 buf)       # 給 buffer 就附加在後面
(ffi/malloc 32) (ffi/free p) # GC 不管，自己 free
(ffi/pointer-buffer p 32 32 0) # 裸記憶體當 buffer 讀寫
```

### out 參數 / struct 回傳

```janet
(def out (buffer/new-filled (ffi/size ts))) # ★ 不是 buffer/new
(ffi/call f (ffi/signature :default :int :int :ptr) 0 out)
(ffi/read ts out)

(def div-t (ffi/struct :int :int))    # 回傳 struct by value
(ffi/call d (ffi/signature :default div-t :int :int) 17 5) ;=> (3 2)
```

### `char*` → 字串

```janet
# 回傳型別寫 :string 就自動轉（但 C 回 NULL 會 segfault）
# 拿到 :ptr 時：
(ffi/read :string (ffi/write :ptr p))  # ✓
(ffi/read :string p)                   # ✗ 會炸
```

| 症狀 | 原因 / 正解 |
|---|---|
| 回傳 `:string` 卻 segfault | C 回了 NULL。改用 `:ptr`（NULL → `nil`）再自己轉。 |
| `ffi/call` 無訊息 segfault | `ffi/lookup` 打錯名字會**安靜回 nil**，先檢查。 |
| `:size` 回來不能算術 | 是 `core/u64`，用 `(int/to-number n)`。 |
| C 寫了但 Janet 讀不到 | `(buffer/new n)` 長度是 0，要 `(buffer/new-filled n)`。 |
| 傳出去的 buffer 之後變垃圾 | Janet buffer 一長大就 realloc。C 端長期持有要 `ffi/malloc`。 |

回呼只有 `ffi/trampoline`（限 `void f(void*ctx, void*userdata)` 一種簽名），要正經做回呼寫 native 模組。細節與可跑範例：`docs/10`、`examples/ffi-pointers.janet`。
