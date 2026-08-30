# 10b · FFI：型別、指標與記憶體

[← 10 與 C 互通](10-c-互通.md)｜下一篇：[10c 字串回傳與地雷合輯](10c-ffi-字串與地雷.md)

FFI 最難的部分。C 那邊沒有 GC、沒有邊界檢查，錯了不會報錯只會壞掉，
所以這一篇的每個小節都值得先看完再動手。

## 一之二、型別、指標與記憶體（FFI 最難的部分）

### 型別關鍵字全表

| 類別 | 關鍵字 | 大小（x86-64） |
|------|--------|---------------|
| 空 | `:void` | 0（只能當回傳型別） |
| 布林 | `:bool` | 1 |
| C 整數別名 | `:char` `:short` `:int` `:long` | 1 / 2 / 4 / 8 |
| 無號別名 | `:uchar` `:ushort` `:uint` `:ulong` `:size` | 1 / 2 / 4 / 8 / 8 |
| 明確寬度 | `:s8 :s16 :s32 :s64` `:u8 :u16 :u32 :u64` | 1/2/4/8 |
| 浮點 | `:float` `:double` | 4 / 8 |
| 指標 | `:ptr` | 8 |
| C 字串 | `:string` | 8（就是 `const char*`） |

用 `(ffi/size t)` / `(ffi/align t)` 查——**不要用猜的**，跨平台會不一樣。
沒有 `:void*`（用 `:ptr`）、沒有 `:wchar`、沒有 `long double`。

**複合型別**：

```janet
(ffi/struct :long :long)     # struct { long; long; }      size 16
(ffi/struct :char :int :ptr) # 會自動照 C 規則補 padding    size 16, align 8
@[:char 4]                   # 陣列型別：char[4]           size 4
(ffi/struct (ffi/struct :int :int) @[:char 4] :double)  # 巢狀也行 size 24
```

> `(ffi/size [:int 4])` 會噴 `bad native type`——陣列型別要用 **`@[]`（array）**，
> 不是 `[]`（tuple）。tuple 在 FFI 裡另有含意。

### 位元組層：`ffi/write` / `ffi/read`

這兩個是 Janet 值 ↔ 原始記憶體的橋，也是「造一個 C struct 出來」的唯一辦法：

```janet
(def ts (ffi/struct :long :long))
(def b (ffi/write ts [7 8]))     # => @"\a\0\0\0\0\0\0\0\b\0\0\0\0\0\0\0"
(ffi/read ts b)                  # => (<core/s64 7> <core/s64 8>)
```

`(ffi/write type data &opt buffer index)`——不給 buffer 就新開一個；給了就**附加在後面**，
所以可以連續寫出一段 C 記憶體佈局：

```janet
(def buf @"")
(ffi/write :int 7 buf)
(ffi/write :int 9 buf)
(ffi/read :int buf 0)   # => 7
(ffi/read :int buf 4)   # => 9    第三參數是 byte offset
```

巢狀 / 陣列成員要用巢狀的 Janet 資料，**字串不能直接塞進 `char[4]`**：

```janet
(ffi/write outer [[1 2] [97 98 99 0] 3.5])   # ✓
(ffi/write outer [[1 2] "abcd"      3.5])    # ✗ expected array or tuple
```

### out 參數：直接把 Janet buffer 當指標傳

C 慣用「你給我一塊記憶體、我填給你」。Janet 這邊開一個夠大的 buffer 傳成 `:ptr` 就好：

```janet
(def libc (ffi/native "libc.so.6"))
(def timespec (ffi/struct :long :long))
(def out (buffer/new-filled (ffi/size timespec)))     # ★ new-filled，不是 buffer/new
(ffi/call (ffi/lookup libc "clock_gettime")
          (ffi/signature :default :int :int :ptr) 0 out)   # => 0
(def [sec nsec] (ffi/read timespec out))
```

> `(buffer/new n)` 只是**預留容量**、長度仍是 0；C 會往裡面寫但 Janet 這邊 `length` 是 0，
> `ffi/read` 讀不到。要 `(buffer/new-filled n)` 真的填出 n 個位元組。

### struct 傳值 / 回傳值

把 struct 型別直接當簽名裡的回傳或參數型別即可，Janet 幫你拆組：

```janet
(def div-t (ffi/struct :int :int))     # C: typedef struct { int quot; int rem; } div_t;
(ffi/call (ffi/lookup libc "div")
          (ffi/signature :default div-t :int :int) 17 5)   # => (3 2)
```

### 手動記憶體：`ffi/malloc` / `ffi/free` / `ffi/pointer-buffer`

要一塊**不受 GC 管**的記憶體（C 那邊要長期持有時）：

```janet
(def mem (ffi/malloc 32))            # => <pointer 0x…>，nil 表示 size 0
(def view (ffi/pointer-buffer mem 32 32 0))   # 把它當成 Janet buffer 來讀寫
(buffer/blit view "hello\0" 0)
(ffi/read :string (ffi/write :ptr mem))       # => "hello"
(ffi/free mem)                       # ★ 一定要自己 free
```

`(ffi/pointer-buffer pointer capacity &opt count offset)` 做出一個**不由 GC 配置/釋放**的
buffer view：`capacity` 是那塊記憶體有多大、`count` 是要當成幾個位元組長。超過 capacity
的擴充會報錯（不會 realloc 到別處，因為那塊不是 Janet 的）。

## 可跑範例

`janet examples/ffi-pointers.janet`——型別大小、struct、out 參數、手動記憶體、
`char*` 轉字串，本篇每一節都跑得到。
