# spork/date、spork/cron ・ 日期運算與排程

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/date`（14 個）是把內建 `os/date` 那種原始的日期 struct，包成好操作的日期運算
（加減、比較、格式化）；`spork/cron`（3 個）解析 cron 運算式（**cron 運算式**——就是
`crontab` 裡那種 `分 時 日 月 週` 五（或六）個欄位排程字串）、判斷某個時間點對不對得上。
隨機抽樣的 `spork/randgen` 另收在 [randgen-隨機抽樣.md](randgen-隨機抽樣.md)。內建
`os/date` 本身（`:year` `:month` 這些欄位、`os/mktime`／`os/strftime`）已經在
[os-時間.md](../os-時間.md) 講過，這裡不重複，只補 spork 多做了什麼。

## spork/date

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `utc-now` | `(utc-now)` | 現在時間，UTC |
| `local-now` | `(local-now)` | 現在時間，本地時區 |
| `date?` | `(date? date)` | 檢查是不是一個「合法日期」struct（有 `:year` `:month` 等必要欄位） |
| `assert-date` | `(assert-date date)` | 同 `date?`，但不合法就丟 error（合法就把 `date` 原樣傳回） |
| `add` | `(add date &named years months days hours minutes seconds)` | 對日期加時間，回傳新的日期 struct |
| `sub` | `(sub date &named years months days hours minutes seconds)` | 減時間 |
| `diff` | `(diff later-date earlier-date)` | 兩個日期相差幾秒（`later - earlier`，早的減晚的會是負數） |
| `compare-dates` | `(compare-dates d1 d2)` | `d1` 比 `d2` 早回 `-1`、晚回 `1`、一樣回 `0` |
| `lt` | `(lt & dates)` | 檢查一串日期是不是遞增排列 |
| `gt` | `(gt & dates)` | 檢查一串日期是不是遞減排列 |
| `between?` | `(between? date start end)` | `date` 是否落在 `start` 到 `end` 之間 |
| `leap-year?` | `(leap-year? year)` | 是不是閏年（照公曆規則） |
| `from-string` | `(from-string date-str format-str)` | 依格式字串把一段文字解析成日期 struct |
| `to-string` | `(to-string date format-str)` | 依格式字串把日期 struct 轉成文字 |

### `from-string` / `to-string` 的格式代碼

⚠ 官方 docstring 寫「`y` = 年份（2 或 4 碼）」容易誤會成「打一個 `y` 字母」，
**實測發現這是誤導**：格式碼要打**兩個或四個 y 疊起來**（`yy` 或 `yyyy`），單一個 `y`
根本不會被辨識、會直接留在輸出裡原樣印出來，或讓 `from-string` 直接丟「無法比對格式」的錯誤。
`m`（分鐘）、`s`（秒）也一樣，必須疊兩個字（`mm`／`ss`），單一個字母不算數：

| 代碼 | 意義 |
|---|---|
| `yy` / `yyyy` | 年（2 碼／4 碼） |
| `M` / `MM` / `MMM` / `MMMM` | 月（數字 1～4 碼，或英文縮寫／全名） |
| `d` / `dd` | 日 |
| `H` / `HH` | 時，24 小時制 |
| `h` / `hh` | 時，12 小時制（配合 `am`/`pm`） |
| `mm` | 分（一定要兩碼） |
| `ss` | 秒（一定要兩碼） |
| `am` / `pm` | 上午／下午標記 |
| 其他字元 | 當分隔符號，原樣保留（`from-string` 會忽略、`to-string` 會照印） |

## spork/cron

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `parse-cron` | `(parse-cron str)` | 把 cron 運算式字串解析成內部的排程物件（一堆 bitmask，不是人看得懂的格式） |
| `check` | `(check cron &opt time local)` | 給定的時間點是否符合這個排程 |
| `next-timestamp` | `(next-timestamp cron &opt time local)` | 這個排程「下一次」會在什麼時間點觸發 |

## 實測範例：date

```janet
(import spork/date)

(date/utc-now)
# => {:dst false :hours 15 :minutes 44 :month 7 :month-day 28
#     :seconds 40 :week-day 6 :year 2026 :year-day 240}
# 注意 :month 跟 :month-day 都是 0-indexed（8 月印成 7、29 號印成 28），
# 這是內建 os/date 的行為，spork/date 原樣沿用，細節見 os-時間.md。

(date/date? (date/utc-now))     # => true
(date/date? @{:a 1})            # => false

(def d (date/utc-now))
((date/add d :days 1) :month-day)   # => 29（原本 28 加一天）
(date/diff (date/add d :hours 3) d) # => 10800   3 小時 = 10800 秒
(date/leap-year? 2024)  # => true
(date/leap-year? 1900)  # => false   雖然能被 4 整除，但百年不閏（公曆規則的例外）
(date/leap-year? 2000)  # => true    百年可被 400 整除才閏

(date/from-string "2026-08-29 15:30:00" "yyyy-MM-dd HH:mm:ss")
# => {:year 2026 :month 7 :month-day 28 :hours 15 :minutes 30 :seconds 0 ...}

(date/to-string (date/utc-now) "yyyy-MM-dd HH:mm:ss")
# => "2026-08-29 15:45:15"
```

## 實測範例：cron

```janet
(import spork/cron)

(def c (cron/parse-cron "*/15 * * * *"))
c
# => ("*/15 * * * *" "\x01\x80\0@\0 \0\0" "\xFF\xFF\xFF" "\xFF\xFF\xFF\x7F" "\xFF\x0F" "\xFF"
#     "\x01\0\0\0\0\0\0\0" false)
# 解析結果是一串 bitmask buffer，不是人讀得懂的格式，不要期待印出來能看懂——
# 有需要就直接呼叫 check / next-timestamp，不要自己去拆這個 tuple。
```

⚠ `cron/check` 有個容易踩的坑：cron 運算式**預設只有五個欄位**（分時日月週），
沒有「秒」這欄，這時候 `parse-cron` 會把秒欄預設成「只在第 0 秒算數」。也就是說，
拿一個帶著非 0 秒數的時間戳去 `check`，就算分鐘完全對得上也會回傳 `false`：

```janet
(def c (cron/parse-cron "*/15 * * * *"))
(def ts-任意秒 (os/mktime (os/date (os/time) true) true))  # 假設現在是 xx:45:36
(cron/check c ts-任意秒 true)   # => false   秒數不是 0，卡在秒欄

(def ts-整分 (os/mktime (merge (os/date (os/time) true) {:seconds 0}) true))
(cron/check c ts-整分 true)     # => true    分鐘 45 % 15 = 0，且秒數落在 0
```

```janet
(def c (cron/parse-cron "0 0 * * *"))   # 每天 00:00
(def ts (os/mktime (os/date)))
(- (cron/next-timestamp c ts) ts)       # => 29671   離下一次觸發還有幾秒
```
