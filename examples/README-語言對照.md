# examples · 從別的語言過來的對照範例

[← examples 目錄](README.md)｜教學索引 [從別的語言過來](../docs/從別的語言過來-索引.md)

七支範例，每支都是**逐列印出「原本那個語言怎麼寫 → Janet 怎麼寫 → 實際跑出來是什麼」**。
跑法跟其他範例一樣：`janet examples/<檔名>`，全部離線、exit 0。

| 檔 | 主題（★＝最值得看，⚠＝實測踩到的坑）|
|----|------|
| [`early-exit.janet`](early-exit.janet) | `return`／`break`／`continue` 九個情境「C → Janet → 實際結果」，⚠ `(break 值)` 值被丟掉、⚠ `defer` 裡的 `break` 跳不出 `each`、`label` 跨函式實測 |
| [`compare-c.janet`](compare-c.janet) | 從 C 過來的逐列對照：數字、字串、陣列、位元、enum、可變參數、assert，錯誤訊息原文照印 |
| [`compare-lua.janet`](compare-lua.janet) | 從 Lua 過來的逐列對照：0-based、`%` 差異、prototype、pcall→`protect`、coroutine→fiber |
| [`compare-go.janet`](compare-go.janet) | 從 Go 過來的逐列對照：err 慣例、slice 拷貝、`%t` 印型別、`ev/go` 不交錯、⚠ chan-close 掉資料、select／cancel／thread-chan |
| [`compare-python.janet`](compare-python.janet) | **從 Python 過來必看**：容器、切片、推導、字典、字串並排對照，★ ⚠ `(slice a 1 -1)` 不等於 `a[1:-1]` |
| [`compare-python-fn.janet`](compare-python-fn.janet) | Python 對照②：參數五形式、decorator、generator 對 fiber、itertools、`try`／`protect`／`defer`，★ Python 的可變預設參數坑在這裡不存在 |
| [`compare-python-oop.janet`](compare-python-oop.janet) | Python 對照③：prototype 當 class、`isinstance` 自己走原型鏈、duck typing、pathlib／json／re／datetime／subprocess 對照 |

配的教學：[01d](../docs/01d-提早離開-return-break-continue.md)、
[43](../docs/43-從-C-C++-過來.md)、[44](../docs/44-從-Lua-過來.md)、
[45](../docs/45-從-Go-過來.md)、[46](../docs/46-從-Python-過來.md)。
