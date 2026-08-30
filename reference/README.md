# reference · 查「有哪些可用」

**這裡是「文檔」，不是教學。**兩者分工：

| | 目的 | 在哪 |
|---|------|------|
| **教學** | 讓你**掌握概念**——為什麼這樣設計、什麼時候該用哪個、會踩什麼坑 | [`docs/`](../docs/README.md) |
| **文檔**（這裡） | **所有可用的東西**——某個領域每一個函式的簽名、一句話說明、實測範例 | `reference/` |
| **速查** | 一眼掃完的常用寫法 | [`html/`](../html/index.html) |
| **抄用** | 「我要做 X，抄哪段」 | [`snippets/`](../snippets/README.md) |

**先看教學建立概念，之後回來查這裡。**直接讀這裡會被淹沒——一份清單有六十幾個函式，
它的目的是「你知道有這個東西、忘了怎麼用時查得到」，不是拿來從頭讀的。

## 有哪些

| 檔 | 收什麼 | 對應教學 |
|----|--------|----------|
| [序列與集合.md](序列與集合.md) | 轉換／篩選與尋找／聚合：`map` `filter` `keep` `reduce` `accumulate` `seq` `count` `find` `sum` `mean` `extreme`… | [25 序列工具](../docs/25-序列工具.md) |
| [序列與集合b-切割與重排.md](序列與集合b-切割與重排.md) | 切割／排序／去重分組分塊／型別判斷：`take` `drop` `slice` `sort` `distinct` `frequencies` `group-by` `partition` `flatten` `range`… | 同上 |
| [序列與集合c-字典與組合.md](序列與集合c-字典與組合.md) | 字典操作／組合函式／走訪：`keys` `values` `kvs` `invert` `merge` `zipcoll` `get-in` `juxt` `comp` `partial` `walk`… | 同上 |
| [斷言與錯誤.md](斷言與錯誤.md) | `assert` `assertf` `error` `errorf` `protect` `try` `signal` `propagate` `defer` `edefer`… | [23 測試怎麼寫](../docs/23-測試怎麼寫.md)、[20 錯誤處理](../docs/20-錯誤處理與資源管理.md) |
| [os-時間.md](os-時間.md) | `os/time` `os/date` `os/mktime` `os/clock` `os/strftime` `os/sleep`，含 `os/date` 欄位表與 `strftime` 格式碼表 | [24 時間與日期](../docs/24-時間與日期.md) |
| [math-數學與隨機.md](math-數學與隨機.md) | **全部 53 個 `math/*`**：常數、取整、冪與對數、三角雙曲、特殊函式、整數工具、隨機數 | [26 隨機數](../docs/26-隨機數.md) |
| [spork/](spork/README.md) | **spork 常用模組的實測筆記**（不求窮盡，最全的在[官方 repo](https://github.com/janet-lang/spork)） | [27 spork 全覽](../docs/27-spork-全覽.md) |

⚠ **上面那五份跟 `spork/` 的標準不一樣**：前者是 Janet **內建**的東西，數量固定、
可以窮盡（而且真的對著 `root-env` 逐一核過）；`spork/` 是**第三方庫**，
會改版、會長新東西，這裡只挑常用的記錄實測結果，**完整清單一律以官方為準**。

## 這些清單怎麼來的

**不是憑記憶寫的**，是從 Janet 1.41.2 執行期的 `root-env` 實際列舉出來的：

```janet
(each k (sort (keys root-env))
  (when (symbol? k)
    (print k "\t" (first (string/split "\n" (or (get (get root-env k) :doc) ""))))))
```

這台機器上共 **703 個** root-env 綁定。每一份文檔都對著這張表逐一核過，
**每個範例都真的跑過、輸出照抄實際結果**——所以你看到的 `=>` 右邊是真的，不是想當然耳。

> 想自己查某個函式：REPL 裡 `(doc 函式名)` 最快，這裡是「我不知道有什麼可用」時才需要的。
> 補完新領域時請照同樣的做法：先列舉、再逐一跑過、才寫進來。

## ⚠ 讀這裡會遇到的一件事

範例裡印巢狀結構用的是 `pp` 或 `%q`，它們印的是 **Janet 表示法**——
**中文字串會被逃逸成 `\xE5\xA3\x9E` 這種 byte 序列**：

```janet
(protect (assert false "壞了"))   # => (false "\xE5\xA3\x9E\xE4\xBA\x86")
```

字串本身沒壞，只是印法如此。要看中文就把字串取出來用 `%s` 印。
細節見 [18 字串與 buffer](../docs/18-字串與-buffer.md)。
