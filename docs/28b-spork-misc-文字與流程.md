# 28b · spork/misc（二）文字、表格與流程

[← 28 spork/misc 順手工具](28-spork-misc-順手工具.md) 講的是**處理資料**的那半
（字典操作、洗牌、取元素與排序）；這篇是**處理文字與控制流程**的那半。

```janet
(import spork/misc)
```

## 一、字串小工具

```janet
(misc/trim-prefix "foo-" "foo-bar")   # => "bar"     沒這個前綴就原樣回傳
(misc/trim-suffix ".txt" "a.txt")     # => "a"
(misc/string->int "ff" 16)            # => 255       第二參是進位
(misc/int->string 255 16)             # => "ff"
```

`dedent` 把多行字串的共同縮排砍掉——寫巢狀程式碼裡的長字串時很有用：

```janet
(misc/dedent ``
    第一行
      第二行縮排
    第三行
``)
# => "第一行\n  第二行縮排\n第三行"   ← 共同的四格砍掉，相對縮排留著
```

## 二、印表格

```janet
(misc/print-table [{:名字 "Alice" :年齡 30} {:名字 "Bob" :年齡 25}])
```

```
╭─────┬────╮
│ 名字│年齡│
╞═════╪════╡
│Alice│  30│
│  Bob│  25│
╰─────┴────╯
```

⚠ **中文會對不齊**。它算欄寬是按 byte／字元數，但中文字在終端機佔**兩格**寬，
所以有中文的欄位框線會歪掉（上面那個表就是實際輸出，自己看框線）。
純 ASCII 的表格才對得齊。

**缺的那塊在 `spork/rawterm`**：`(rawterm/monowidth s)` 回的是**顯示寬度**
（`"中文abc"` → 7，而 `length` 給的是 byte 數 9）。拿它自己補空白就對齊了：

```janet
(defn pad [s w]
  (string s (string/repeat " " (max 0 (- w (rawterm/monowidth s))))))
```

前後對照與 `slice-monowidth`（按顯示寬度切、不會把中文切一半）見
[41 spork 終端與 shell](41-spork-終端與-shell.md)。

`format-table` 是同一件事但寫進 buffer 而不是印出來。

## 三、捕捉輸出與條件流

```janet
(misc/capout (print "被吃掉了"))   # => @"被吃掉了\n"   把 stdout 收進 buffer
(misc/caperr (eprint "錯誤"))       # 同理，收 stderr
```

測試「這支函式印了什麼」時很好用（配合 [23 測試怎麼寫](23-測試怎麼寫.md)）。

```janet
(misc/cond-> 5 true inc false (* 100))   # => 6   條件成立才套用那一步
(misc/until (= i 3) (print i) (++ i))    # while 的相反：條件成立就停
```

`cond->` 是[執行緒巨集](01c-解構與執行緒巨集.md)的條件版——一串「這個開關開著才做這步」的轉換。

## 四、一個設計得很聰明的 logger

```janet
(misc/log :debug "算出來是 %q" 結果)
```

它的「等級」**就是 dyn 的 key**：只有在 `(dyn :debug)` 被設成一個 stream 時才會印，
否則**整句什麼都不做**。所以：

```janet
(setdyn :debug stdout)    # 開啟 debug log
(setdyn :debug nil)       # 關掉，零成本
```

不用設定檔、不用 logger 物件，開關就是一個動態變數（見 [12c dyn](12c-dyn.md)）。

⚠ 但 `log` 自己的文件字串舉的例子是 `%V`，而 **`%v`／`%V` 印的是位址不是內容**
（`<array 0x...>`）。要看內容用 **`%q`**——跟 [01 的 print vs pp](01-語言速成.md) 是同一個坑。

## 五、其他值得知道的

| 函式 | 幹嘛的 |
|------|--------|
| `make-id` | 產生像 `:req-45EAA89BFBA964F7691F` 的唯一 ID，可帶前綴 |
| `make` | 用原型建物件，配合 [22 原型與方法](22-原型與方法.md) |
| `defs` / `vars` | 一次定義多個綁定：`(misc/defs a 1 b 2)` |
| `dfs` | 深度優先走訪巢狀資料，只在葉節點呼叫你的函式 |
| `pivot` / `column-combine` / `format-table` | 把資料當表格處理（data frame 風格） |


## 可跑範例

```sh
janet examples/spork-tour.janet    # misc 與其他十三個模組各跑一段
```

下一步：[29-spork-資料與文字.md](29-spork-資料與文字.md)。
