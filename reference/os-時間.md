# os ・ 時間

[← reference 索引](README.md)

這份收 `os/*` 裡跟時間相關的 6 個：`os/time` `os/date` `os/mktime` `os/clock` `os/strftime` `os/sleep`。全部實測於 Janet 1.41.2、時區 Asia/Taipei（UTC+8），epoch 統一用 `1787976000`（UTC 2026-08-29 04:00:00）示範。對應教學 docs/24-時間與日期.md。

## 六個函式一覽

| 名字 | 簽名 |
|---|---|
| `os/time` | `(os/time)` |
| `os/date` | `(os/date &opt time local)` |
| `os/mktime` | `(os/mktime date-struct &opt local)` |
| `os/clock` | `(os/clock &opt source format)` |
| `os/strftime` | `(os/strftime fmt &opt time local)` |
| `os/sleep` | `(os/sleep n)` |

## os/time：現在的 unix 秒數

```
(os/time)  # => 1788016777    number，整數，UTC 1970-01-01 起算的秒數
```

## os/date：秒數轉成日期 struct

`local` 不給或給 `false` → **UTC**；給 `true` → 本機時區（這裡是 UTC+8）。

```
(os/date 1787976000)        # => {:year 2026 :month 7 :month-day 28 :hours 4  ...}  (UTC)
(os/date 1787976000 true)   # => {:year 2026 :month 7 :month-day 28 :hours 12 ...}  (本機 +8)
```

⚠ `time` 只能是整數秒（`(os/date 1787976000.7)` 會直接報錯 `can not convert number ... to 64 bit signed integer`），不接受小數。

## os/date 回傳的 struct，每個欄位

| 欄位 | 範圍／說明 | 本例實測值 |
|---|---|---|
| `:year` | 完整西元年（不像 C 的 `tm_year` 要 +1900，這裡就是 `2026`） | `2026` |
| `:month` | **0-based**：`0`=一月 … `11`=十二月 | `7`（八月） |
| `:month-day` | **0-based**：`0`=該月 1 號 | `28`（29 號） |
| `:hours` | `0`~`23` | `4`（UTC）／`12`（本機） |
| `:minutes` | `0`~`59` | `0` |
| `:seconds` | `0`~`59` | `0` |
| `:week-day` | 0-based，`0`=週日 … `6`=週六（實測 2026-08-29 週六 => 6，隔天週日 => 0，跟 `os/strftime "%w"` 同一套編號） | `6` |
| `:year-day` | 0-based，`0`=當年 1/1（實測 8/29 是平年第 241 天，回傳 `240`） | `240` |
| `:dst` | boolean，是否夏令時間。台北沒有夏令時間，實測全部是 `false`，沒能實測到 `true` 的情況 | `false` |

⚠ **`:month` 與 `:month-day` 都是 0-based**，跟人類講話「8 月 29 日」的 1-based 差一位，換算時很容易漏減/漏加 1。

## os/mktime：日期 struct 轉回秒數（os/date 的反操作）

```
(os/mktime (os/date 1787976000))        # => 1787976000   UTC struct，不給 local，round-trip 成功
(os/mktime (os/date 1787976000 true) true)  # => 1787976000   local struct + local true，也 round-trip 成功
(os/mktime @{:year 2026 :month 0 :month-day 0 :hours 0 :minutes 0 :seconds 0})  # => 1767225600（2026-01-01 UTC 00:00:00）
```

只需要 `:year :month :month-day :hours :minutes :seconds` 幾個欄位，`:week-day` `:year-day` `:dst` 可以省略。

⚠ **`local` 參數要跟建 struct 時用的 `local` 一致，不然結果整段位移一個時區的秒數**（這裡是 8 小時 = 28800 秒）：

```
(os/mktime (os/date (os/time) true))        # 用 local struct，但沒說 local -> 當成 UTC 解讀，多加了 8 小時，錯！
(os/mktime (os/date (os/time) true) true)   # 用 local struct，也說 local -> 正確
```

## os/clock：三種時鐘來源 × 三種輸出格式

`source`（`&opt`，省略預設 `:realtime`）：

| 值 | 白話 |
|---|---|
| `:realtime` | 現在的 unix 時間，跟 `os/time` 一樣的概念但帶小數（奈秒精度） |
| `:monotonic` | 單調時鐘：只會一直往前走，系統時鐘被手動調整或 NTP 校時都不影響它，適合用來算「經過了多久」而不是「現在幾點」 |
| `:cputime` | 這個程式（行程）實際吃到的 CPU 時間，不是牆上時間 |

`format`（`&opt`，省略預設 `:double`）：`:double`（一個浮點秒數）／`:int`（取整數秒）／`:tuple`（`(秒 奈秒)` 兩個整數的 tuple）。

```
(os/clock)                    # => 1788016815.25923
(os/clock :realtime)          # => 1788016811.18745
(os/clock :monotonic)         # => 59774.277545772     這台機器開機後(或某個起點)經過的秒數，不是 unix time
(os/clock :cputime)           # => 0.00111143
(os/clock :realtime :int)     # => 1788016811
(pp (os/clock :realtime :tuple))    # => (1788016829 121527549)
(os/clock :bogus)             # => error: expected :realtime, :monotonic, or :cputime, got :bogus
```

## os/strftime：格式化日期字串

`local` 語義跟 `os/date` 一樣：不給／`false` = UTC，`true` = 本機時區。以下是**實測支援**的格式碼（逐一 `janet -e` 跑過，會噴 `invalid conversion specifier` 的一律不列）：

| 碼 | 意思 | 實測（`1787976000`，UTC） |
|---|---|---|
| `%Y` | 4 位數西元年 | `2026` |
| `%y` | 2 位數年 | `26` |
| `%m` | 月，2 位數，01~12 | `08` |
| `%d` | 日，2 位數 | `29` |
| `%j` | 這一年第幾天，**1-based**，3 位數 | `241`（注意跟 struct 的 `:year-day` 差 1，那個是 0-based） |
| `%H` | 24 小時制小時 | `04` |
| `%I` | 12 小時制小時 | `04` |
| `%M` | 分鐘 | `00` |
| `%S` | 秒 | `00` |
| `%p` | AM/PM | `AM` |
| `%a` | 星期幾縮寫 | `Sat` |
| `%A` | 星期幾全名 | `Saturday` |
| `%b` | 月份縮寫 | `Aug` |
| `%B` | 月份全名 | `August` |
| `%w` | 星期幾數字，0=週日~6=週六 | `6` |
| `%U` `%W` | 一年中第幾週 | `34` |
| `%x` | 慣用日期格式 | `08/29/26` |
| `%X` | 慣用時間格式 | `04:00:00` |
| `%c` | 慣用完整日期時間 | `Sat Aug 29 04:00:00 2026` |
| `%Z` | 時區名 | `GMT`（UTC）／`CST`（本機 true 時） |
| `%%` | 字面上的 `%` | `%` |

⚠ **實測不支援**（跑了會 `error: invalid conversion specifier`，即使是常見的 C strftime 碼也一樣）：`%s`（unix 秒數）、`%e` `%n` `%t` `%u` `%z` `%D` `%F` `%T` `%r` `%R` `%V` `%G` `%C`。想要 unix 秒數字串就用 `(string (os/time))`，想要 `YYYY-MM-DD` 就自己組 `%Y-%m-%d`。

## os/sleep：暫停執行

```
(os/sleep 0.2)   # 實測：真的睡了約 0.2 秒（前後量 os/clock 差 0.200095653533936）
(os/sleep 0)     # => 合法，立刻返回，回傳 nil
(os/sleep -1)    # => error: invalid argument to sleep
```

`n` 可以是帶小數的秒數；負數會直接報錯，不是「不睡」。
