# ffi ・ 全部 20 個

[← reference 索引](README.md)

對應教學：[10 C 互通](../docs/10-c-互通.md)、[10b 型別與指標](../docs/10b-ffi-型別與指標.md)、
[10c 字串與地雷](../docs/10c-ffi-字串與地雷.md)、[10d native 與嵌入](../docs/10d-native-與嵌入.md)。
可跑範例：[`examples/ffi-demo.janet`](../examples/ffi-demo.janet)、
[`examples/ffi-pointers.janet`](../examples/ffi-pointers.janet)。

> 對著 `root-env` 逐一核過，`ffi/*` 共 20 個。**不編譯任何 C**，直接呼叫現成的
> 共享庫；要寫 C 擴充模組是另一條路（`native`，見 [10d](../docs/10d-native-與嵌入.md)）。

## 最短路徑：載入 → 描述簽名 → 呼叫

```janet
(def libc (ffi/native "libc.so.6"))
(def sig (ffi/signature :default :int :int))
(ffi/call (ffi/lookup libc "abs") sig -7)     # => 7
```

| 函式 | 簽名 | 說明 |
|------|------|------|
| `ffi/native` | `(ffi/native &opt path)` | 載入 .so／.dll，**不跑裡面任何初始化程式碼**。`path` 給 `nil` 就開目前這支執行檔。回 `:core/ffi-native` |
| `ffi/lookup` | `(ffi/lookup native name)` | 查符號，回 `:pointer`；**查不到回 `nil` 不丟錯** |
| `ffi/signature` | `(ffi/signature cc ret & args)` | 做一份簽名，型別是 `:core/ffi-signature` |
| `ffi/call` | `(ffi/call pointer sig & args)` | 用簽名把 Janet 值轉成機器型別再呼叫 |
| `ffi/close` | `(ffi/close native)` | 釋放 native 物件。⚠ 之後再用它查到的指標是**未定義行為** |
| `ffi/calling-conventions` | `(ffi/calling-conventions)` | 這台機器支援哪些呼叫慣例 |

```janet
(ffi/calling-conventions)   # => @[:sysv64 :none]
```

⚠ `:none` 只是佔位，不能真的拿來呼叫。x86-64 Linux 上可用的是 `:sysv64`，
`:default` 是「挑這台機器的預設那個」。

## 型別與大小（2 個）

常用型別關鍵字：`:void` `:bool` `:char` `:int` `:uint` `:long` `:size` `:float`
`:double` `:s8`～`:s64` `:u8`～`:u64` `:ptr` `:string`。

```janet
(ffi/size :int)      # => 4
(ffi/size :ptr)      # => 8
(ffi/size :bool)     # => 1
(ffi/size :void)     # => 0
(ffi/align :double)  # => 8
```

⚠ **永遠用 `ffi/size` 問，不要用猜的**——跨平台會不一樣。

⚠ 回傳型別寫 `:size` 時，拿回來的是 **abstract `:core/u64`**，不是普通數字，
`%j` 印不出來也不能直接拿去做算術；要普通數字就把回傳型別寫成 `:int`，
或事後 `int/to-number`（見 [數字型別與位元](數字型別與位元.md)）。

## struct 與讀寫記憶體（3 個）

| 函式 | 說明 |
|------|------|
| `ffi/struct` | `(ffi/struct & types)`，回 `:core/ffi-struct`；padding 照 C 規則算好 |
| `ffi/write` | `(ffi/write type data &opt buffer index)`，把 Janet 值排成記憶體佈局，回 buffer |
| `ffi/read` | `(ffi/read type bytes &opt offset)`，反過來；`bytes` 也可以是裸指標（不安全）|

```janet
(ffi/write :int 258)                                   # => @"\x02\x01\0\0"
(ffi/read :int (ffi/write :int 7))                     # => 7
(ffi/size (ffi/struct :char :int :ptr))                # => 16
(ffi/align (ffi/struct :char :int :ptr))               # => 8
(ffi/read (ffi/struct :int :int) (ffi/write (ffi/struct :int :int) [1 2]))   # => (1 2)
```

陣列型別要寫成 `@[:char 4]`（array 不是 tuple）。out 參數的做法：
`(buffer/new-filled (ffi/size 型別))` 先把長度填滿，再整個 buffer 當 `:ptr` 傳進去。

## 手動記憶體（3 個）

| 函式 | 說明 |
|------|------|
| `ffi/malloc` | `(ffi/malloc size)` 回 `:pointer`；**GC 不管它，要自己 `ffi/free`**。`size` 為 0 回 `nil` |
| `ffi/free` | `(ffi/free pointer)` 只能拿來還 `ffi/malloc` 給的東西 |
| `ffi/pointer-buffer` | `(ffi/pointer-buffer p capacity &opt count offset)` 把一塊裸記憶體包成 buffer |

⚠ `ffi/pointer-buffer` 做出來的 buffer **不能長大**，超過容量會丟
`buffer cannot reallocate foreign memory`；它也不會替你釋放那塊記憶體。

## 回呼與進階（4 個）

| 函式 | 說明 |
|------|------|
| `ffi/pointer-cfunction` | `(ffi/pointer-cfunction p &opt name file line)` 把裸指標包成 cfunction |
| `ffi/trampoline` | `(ffi/trampoline cc)` 拿一個能當 C callback 的函式指標；簽名固定是 `void f(void *ctx, void *userdata)`，`userdata` 要放 Janet 函式 |
| `ffi/jitfn` | `(ffi/jitfn bytes)` 把一段**架構專屬的機器碼**複製到可執行記憶體，當 `ffi/call` 的指標用 |
| `ffi/context` | `(ffi/context &opt path &named map-symbols lazy)` 設定「接下來 `defbind` 預設綁哪個庫」 |

## 省事的綁定寫法（2 個巨集）

`ffi/defbind-alias` 讓 Janet 這邊的名字跟 C 符號不同。
⚠ **參數順序容易搞反**：`(ffi/defbind-alias C符號 Janet名字 回傳型別 [參數…])`，
**第一個是 C 那邊的名字**。

```janet
(ffi/context "libc.so.6")
(ffi/defbind abs :int [x :int])
(abs -9)                                # => 9
(ffi/defbind-alias strlen c-strlen :int [s :string])
(c-strlen "abcdef")                     # => 6
```

⚠ `ffi/defbind` 會把名字裡的 `-` 換成 `_` 再去查符號，所以
`(ffi/defbind c-strlen …)` 找的是 `c_strlen`，不是 `strlen`。
⚠ 沒先 `ffi/context` 就用 `defbind`，展開當下就丟 `no ffi context found`。
