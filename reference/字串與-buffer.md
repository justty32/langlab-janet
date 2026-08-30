# 字串與 buffer ・ 全部 45 個

[← reference 索引](README.md)

對應教學：[18 字串與 buffer](../docs/18-字串與-buffer.md)、[13 名字型別](../docs/13-symbol-keyword-字串.md)、
[41 中文對齊](../docs/41-spork-終端與-shell.md)。

> 對著 `root-env` 逐一核過：`string/*` **20 個**、`buffer/*` **25 個**，全收。

## 先記三件事

1. **`string` 不可變、`buffer` 可變**。`string/*` 一律**回新的**；`buffer/*` 多半**原地改**。
2. **長度是 byte 數**：`(length "中文")` 是 `6`。字元數與**顯示寬度**又是另外兩個數字。
3. ⚠ **參數順序**：`string/*` 的**被搜尋的字串放最後**（`(string/find patt str)`），
   跟多數語言相反。記法：「先講要找什麼，再講在哪找」。

## `string/*`（20 個）

### 查找

| 函式 | 簽名 | 回什麼 |
|------|------|--------|
| `string/find` | `(string/find patt str &opt start)` | **索引**或 `nil`（不是子字串）|
| `string/find-all` | `(string/find-all patt str &opt start)` | 索引陣列 |
| `string/has-prefix?` | `(string/has-prefix? pfx str)` | 真假 |
| `string/has-suffix?` | `(string/has-suffix? sfx str)` | 真假 |
| `string/check-set` | `(string/check-set set str)` | `str` 是否**只**含 `set` 裡的字元 |

### 切割與組合

| 函式 | 簽名 | 說明 |
|------|------|------|
| `string/split` | `(string/split delim str &opt start limit)` | 分隔符是**字串**不是正則 |
| `string/join` | `(string/join parts &opt sep)` | ⚠ `sep` 省略時是**空字串**不是空白 |
| `string/slice` | `(string/slice bytes &opt start end)` | 吃**負索引**（`-1` 是結尾）|
| `string/repeat` | `(string/repeat bytes n)` | 重複 n 次 |
| `string/reverse` | `(string/reverse str)` | ⚠ 按 **byte** 反轉——中文會壞掉 |

### 取代與修剪

| 函式 | 簽名 | 說明 |
|------|------|------|
| `string/replace` | `(string/replace patt subst str)` | 只換**第一個** |
| `string/replace-all` | `(string/replace-all patt subst str)` | 全換 |
| `string/trim` | `(string/trim str &opt set)` | 兩端；`set` 省略時修空白 |
| `string/triml` / `string/trimr` | 同上 | 只修左／只修右 |

### 大小寫與 byte

| 函式 | 簽名 | 說明 |
|------|------|------|
| `string/ascii-lower` / `string/ascii-upper` | `(… str)` | ⚠ **只動 ASCII**，非 ASCII 原樣 |
| `string/bytes` | `(string/bytes str)` | → byte 數字的 **tuple** |
| `string/from-bytes` | `(string/from-bytes & vals)` | byte 數字 → 字串 |

### 格式化

`(string/format fmt & values)`

| 動詞 | 意思 |
|------|------|
| `%s` | ⚠ **只吃字串類**（string／buffer／symbol／keyword）；餵數字會報 `bad slot` |
| `%v` | 通吃，像 `print` 那樣（容器只給位址）|
| `%d` `%f` `%.2f` `%x` `%o` | 跟 C 的 printf 一樣 |
| `%q` | Janet 可讀表示法——**印容器內容就用這個** |
| `%p` | pretty（會折行縮排）|
| `%j` | 單行 Janet 表示法。⚠ **不是 JSON** |
| `%%` | 一個百分號 |

⚠ **`%q`／`%p`／`%j` 會把中文逃逸**成 `\xE4\xBD\xA0…`——給人看的輸出一律用 `%s`。
⚠ **寬度旗標對 `%j` 無效**（`%-10j` 靜默不生效）：先 `(string/format "%j" x)` 轉字串再排版。

## `buffer/*`（25 個）

### 建立與清空

| 函式 | 說明 |
|------|------|
| `buffer/new` | `(buffer/new capacity)` 預留容量的空 buffer |
| `buffer/new-filled` | `(buffer/new-filled count &opt byte)` 先填滿 |
| `buffer/clear` | 長度歸零（容量留著）|
| `buffer/trim` | 把容量縮到剛好等於長度 |
| `buffer/fill` | `(buffer/fill buffer &opt byte)` 整個填同一個 byte |

### 附加（★ 效能關鍵）

| 函式 | 說明 |
|------|------|
| `buffer/push-string` | 接一段字串。**迴圈裡累積字串一定用它**——用 `string` 是 O(N²)，慢三百倍 |
| `buffer/push` | 通吃：單獨的 byte 或整串 byte 序列 |
| `buffer/push-byte` | 只接單一 byte |
| `buffer/push-at` | `(… buffer index & xs)` 指定位置寫入（覆蓋）|
| `buffer/push-word` | 接機器字 |
| `buffer/popn` | 砍掉尾端 n 個 byte |
| `buffer/blit` | `(… dest src &opt dest-start src-start src-end)` 區塊複製 |
| `buffer/slice` | 取子序列（回**新的 buffer**）|

### 二進位：定長整數與浮點

`buffer/push-uint16` `buffer/push-uint32` `buffer/push-uint64`
`buffer/push-float32` `buffer/push-float64`

簽名都是 `(… buffer order data)`，`order` 是 `:le`／`:be`／`:native`。
⚠ **檔案格式多半是大端序（`:be`）**，照機器序讀會拿到錯的數字
（實例見 [`snippets/binary-png/`](../snippets/binary-png/main.janet)）。

### 位元操作

`buffer/bit` `buffer/bit-set` `buffer/bit-clear` `buffer/bit-toggle`
——簽名都是 `(… buffer index)`，index 是**位元**索引不是 byte 索引。

### 格式化進 buffer

| 函式 | 說明 |
|------|------|
| `buffer/format` | `(… buffer fmt & args)` 附加到尾端 |
| `buffer/format-at` | `(… buffer at fmt & args)` 寫到指定位置 |

## 不在這裡的

**字元數與顯示寬度**不是內建的：字元數自己用 `utf8/prefix->width` 疊
（見 [`snippets/utf8-strings.janet`](../snippets/utf8-strings.janet)），
**顯示寬度**用 `spork/rawterm` 的 `monowidth`／`slice-monowidth`
（中文表格對齊見 [`snippets/aligned-table.janet`](../snippets/aligned-table.janet)）。
正則沒有內建，用 [PEG](../docs/14-peg.md) 或 `spork/regex`。
