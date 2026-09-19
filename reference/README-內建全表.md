# reference · Janet 內建的全表

[← reference 索引](README.md)｜[docs 教學目錄](../docs/README.md)

Janet **內建**的東西：數量固定、可以窮盡，而且真的對著 `root-env` 逐一核過。
spork 那邊是第三方庫、會改版，另收在 [spork/](spork/README.md)，標準不一樣（見 [README](README.md)）。

## 資料與序列

| 檔 | 收什麼 | 對應教學 |
|----|--------|----------|
| [序列與集合.md](序列與集合.md) | 轉換／篩選與尋找／聚合：`map` `filter` `keep` `reduce` `accumulate` `seq` `count` `find` `sum` `mean` `extreme`… | [25 序列工具](../docs/25-序列工具.md) |
| [序列與集合b-切割與重排.md](序列與集合b-切割與重排.md) | 切割／排序／去重分組分塊／型別判斷：`take` `drop` `slice` `sort` `distinct` `frequencies` `group-by` `partition` `flatten` `range`… | 同上 |
| [序列與集合c-字典與組合.md](序列與集合c-字典與組合.md) | 字典操作／組合函式／走訪：`keys` `values` `kvs` `invert` `merge` `zipcoll` `get-in` `juxt` `comp` `partial` `walk`… | 同上 |
| [容器操作.md](容器操作.md) | **全部 37 個** 型別專屬操作（`array/` 15、`table/` 11、`struct/` 5、`tuple/` 6）：增刪／容量／prototype／弱參照；⚠ `concat` 吃單值、`join` 只吃序列 | [02](../docs/02-資料結構.md)、[02b](../docs/02b-方法與-prototype.md) |
| [字串與-buffer.md](字串與-buffer.md) | **全部 45 個**（`string/*` 20 ＋ `buffer/*` 25）：查找／切割／取代／格式動詞表／二進位 push／位元操作；⚠ 參數順序、`%s` 只吃字串類 | [18](../docs/18-字串與-buffer.md) |
| [型別判斷與轉換.md](型別判斷與轉換.md) | **全部 37 個判斷函式** ＋ `(type x)` 的 19 種回傳值 ＋ 轉換表；⚠ **字典存不了 `nil` 值** | [38](../docs/38-型別全表.md)、[13](../docs/13-symbol-keyword-字串.md) |
| [數字型別與位元.md](數字型別與位元.md) | **全部 31 個**：位元 7、`int/*` 4、相等與 hash 5、比較 10、算術 5；⚠ 位元運算是 **32-bit**、`(+ (int/s64 1) 1)` 仍是 `:core/s64` | [21](../docs/21-數字與位元.md)、[36](../docs/36-排序與比較.md) |
| [math-數學與隨機.md](math-數學與隨機.md) | **全部 53 個 `math/*`**：常數、取整、冪與對數、三角雙曲、特殊函式、整數工具、隨機數 | [26 隨機數](../docs/26-隨機數.md) |

## 語言本身

| 檔 | 收什麼 | 對應教學 |
|----|--------|----------|
| [控制流.md](控制流.md) | 條件／`match` 模式表／`loop` 的八個 verb 與八個條件詞／非區域跳出；⚠ 標出哪些是**特殊形式** | [32](../docs/32-條件與模式比對.md)、[32b](../docs/32b-loop-全表.md) |
| [特殊形式與核心巨集.md](特殊形式與核心巨集.md) | **13 個特殊形式**（`def` `var` `fn` `do` `if` `while` `break` `set` `quote` `quasiquote` `unquote` `splice` `upscope`）＋怎麼分辨特殊形式／巨集／函式；⚠ 特殊形式不在 `root-env` 裡、不能當值傳 | [01](../docs/01-語言速成.md)、[08](../docs/08-巨集-macro.md) |
| [特殊形式與核心巨集b-巨集全表.md](特殊形式與核心巨集b-巨集全表.md) | **全部 86 個巨集**的分組索引：定義／綁定／編譯期／條件／迴圈／錯誤／執行緒／數值／跳出／模組／fiber／ffi／dyn／其他；⚠ `/=` 是真除法、`juxt` 是巨集而 `juxt*` 是函式 | [01c](../docs/01c-解構與執行緒巨集.md) |
| [巨集工具與求值.md](巨集工具與求值.md) | **全部 14 個**：`macex` `macex1` `gensym` `eval` `eval-string` `compile` `run-context` `dofile` `parse` `parse-all` `disasm` `asm` `make-env` `curenv`；⚠ `compile` 編不過是**回錯誤表**不丟錯 | [08](../docs/08-巨集-macro.md)、[12b](../docs/12b-切換-env.md) |
| [巨集工具與求值b-parser-與-module.md](巨集工具與求值b-parser-與-module.md) | **全部 28 個**：`parser/*` 13 ＋ `module/*` 10 ＋ `require` `import` `import*` `use` `merge-module`；⚠ 最後一個 token 沒結束符時取不出來、`module/expand-path` 回 buffer | [05e](../docs/05e-import-與模組路徑.md) |
| [斷言與錯誤.md](斷言與錯誤.md) | `assert` `assertf` `error` `errorf` `protect` `try` `signal` `propagate` `defer` `edefer`… | [23 測試怎麼寫](../docs/23-測試怎麼寫.md)、[20 錯誤處理](../docs/20-錯誤處理與資源管理.md) |

## 並行、IO、系統

| 檔 | 收什麼 | 對應教學 |
|----|--------|----------|
| [fiber-與-ev.md](fiber-與-ev.md) | **全部 50 個**（`fiber/` 10 ＋ `ev/` 40）：起任務／等待與取消／channel／鎖／stream；先分清 fiber、ev task、真執行緒三層 | [09](../docs/09-fiber.md)、[15](../docs/15-ev-channel-net.md) |
| [file-與-net.md](file-與-net.md) | `file/*` 9 ＋ `stdin`／`stdout`／`stderr` ＋ 印與讀的家族 19，共 **31 個**；⚠ **半成品**：`net/*` 那 19 個還沒寫，見 [planning](../wf/workflows/planning.md) | [19](../docs/19-檔案與檔案系統.md)、[20b](../docs/20b-資源管理.md) |
| [os-全表.md](os-全表.md) | **全部 48 個 `os/*`**：這台機器／終端機／檔案目錄／權限／子行程／環境變數／POSIX 專屬；⚠ `os/shell` 回 exit code × 256 | [39](../docs/39-跟作業系統打交道.md)、[11](../docs/11-pipeline-signal.md) |
| [os-時間.md](os-時間.md) | `os/time` `os/date` `os/mktime` `os/clock` `os/strftime` `os/sleep`，含 `os/date` 欄位表與 `strftime` 格式碼表 | [24 時間與日期](../docs/24-時間與日期.md) |
| [ffi-全表.md](ffi-全表.md) | **全部 20 個 `ffi/*`**：載入／簽名／呼叫、型別大小、struct 讀寫、手動記憶體、`defbind`；⚠ 回傳型別寫 `:size` 拿到的是 abstract `:core/u64`、`defbind-alias` 第一個參數是 **C 符號** | [10](../docs/10-c-互通.md)、[10b](../docs/10b-ffi-型別與指標.md) |
| [bundle-套件管理.md](bundle-套件管理.md) | **全部 16 個 `bundle/*`**：Janet 內建的套件機制（jpm 之外的官方那套）；5 個鉤子、manifest 欄位、跟 jpm／spork/pm 的分工；⚠ `add-directory` 不建上層目錄 | [05](../docs/05-jpm-與專案.md) |

## PEG

| 檔 | 收什麼 | 對應教學 |
|----|--------|----------|
| [peg-全表.md](peg-全表.md) | `peg/*` **6 個**全收 ＋ `default-peg-grammar` ＋ **比對用 special 21 個**，每個都跑過 `peg/match` | [14 peg](../docs/14-peg.md) |
| [peg-全表b-捕獲.md](peg-全表b-捕獲.md) | **捕獲用 special 21 個**一個不漏：取出文字／位置／分組／累積／替換／回看，每個都跑過 `peg/match` | 同上 |
