# C2 course 第 3、4 章 審閱

審閱者：fable｜日期 2026-09-26｜範圍：`course/3-1-四個容器.md`、`course/3-2-拿放改.md`、`course/3-3-相等與比較.md`、`course/4-1-字串與-buffer.md`、`course/4-2-字串常用招式.md`、`course/4-3-JSON.md`、`examples/course/3-1.janet` ～ `3-3.janet`、`examples/course/4-1.janet` ～ `4-3.janet`

## 總評

六篇課文的程式碼與六支範例檔全部實跑過，輸出跟課文標的 `# =>` 逐行一致，沒有跑不動或輸出寫錯的地方。指定重點（`=` vs `deep=`、struct/table 當 key、字串 vs buffer 的 `=`、JSON key 是 keyword 還是 string）講得都對，而且 4-3 的「忘了給 `true` 全變 nil」那個坑點得很準。最大的問題不在錯，而在 3-2 一句「容器裡不會存 nil」把 table 的規則講成了所有容器的規則，跟同篇下面 `@[1 2 3 nil nil 9]` 自相矛盾；其次 3-3 的 `=` 對照表漏了 buffer，4-1 卻說「3-3 講過」。最值得先修的一件事：把 3-2:62 那句改成只講 table／struct，並在 3-3 的表加一列 buffer。

## 發現

- [中][錯誤] `course/3-2-拿放改.md:62` — 「Janet 的容器裡不會存 `nil` 這個值」只對 table／struct 成立，array 會存：`(array/push @[] nil)` 得 `@[nil]`，同篇 105 行自己就印出 `@[1 2 3 nil nil 9]` — 改成「table 裡不會存 nil」 — [實測]
- [中][結構] `course/3-3-相等與比較.md:11-15` — `=` 對照表只列四個容器與字串，沒有 buffer；`course/4-1-字串與-buffer.md:103` 卻寫「3-3 講過 `=` 對可變的東西比的是身分」，讀者回頭查表找不到 buffer — 表的可變列加上 buffer（`(= "abc" @"abc")` 是 false），或 4-1 改成「同一條規則」而不是「講過」 — [實測]
- [中][錯誤] `course/4-3-JSON.md:9` — 「spork …1-1 裝環境時已經裝好了」，但 `course/1-1-裝好跑起來.md` 全文沒提 spork 與 jpm，1-1 只講 janet 本體；2-3:123 是第一次出現 `(import spork/json)` 且說「第 4、9 單元細講」 — 改成指向 docs/00 或在 4-3 補一行「沒裝的話 `jpm install spork`」 — [實測 grep]
- [低][錯誤] `course/3-3-相等與比較.md:106` — 坑只講「tuple 裡包 array」，struct 一樣：`(= {:a @[1]} {:a @[1]})` 是 false，但 14 行的表把 struct 列為「比內容」，讀者會以為 struct 沒這問題 — 坑改寫成「tuple／struct 只要裡面有一格是 array／table，那一格就走身分」 — [實測]
- [低][難懂] `course/4-2-字串常用招式.md:7` — 「要找的東西放前面，被處理的字串放最後」講成 `string/` 全家的規矩，但 `slice`、`repeat`、`format`、`join`（19 行自己說反過來）都是字串在前，讀者套規則會撞牆 — 限定「`split`／`find`／`replace`／`has-prefix?` 這類拿樣式去比對的」 — [實測]
- [低][錯誤] `course/4-3-JSON.md:78` — 「想送 `null` 得放 keyword `:null`」漏講 array 裡的 nil 會正常編成 null：`(json/encode [nil 1])` 得 `[null,1]`；鍵消失是 table／struct 建構時就丟掉 nil，不是 encode 做的 — 補一句「array 裡的 nil 會變 null，消失的只有鍵值對」 — [實測]
- [低][難懂] `course/3-2-拿放改.md:9` — 說回 `nil` 「跟 Python 的 KeyError、JS 的 undefined 都不太一樣」，但 JS 取不到鍵也是靜靜回 `undefined`，行為其實一樣，只有 Python 會炸 — 改成「跟 Python 會炸不同，跟 JS 回 undefined 類似」 — [疑]
- [低][文風] `course/3-3-相等與比較.md:7` — 「JS 的 `==` 和物件比較」半句話沒講完，讀者不知道 JS 那邊對應的是哪兩個 — 改「JS 物件用 `===` 比的就是身分」或直接刪 JS 那半句 — [疑]
- [低][範例] `course/4-2-字串常用招式.md:56-57` 對 `examples/course/4-2.janet:26` — 課文示範 `(string/slice "hello" 2)` 與 `0 -2`（62 行還特別解釋 -2 的坑），範例檔改成 `-3`，沒有覆蓋課文最容易誤會的負索引例子 — 範例檔加回 `(string/slice "hello" 0 -2)` — [實測]
- [低][結構] `course/4-1-字串與-buffer.md:111-115`、`course/4-2-字串常用招式.md:124-128`、`course/4-3-JSON.md:135-139` — 三篇小練習都沒有 3-x 那句「答案在 `examples/course/4-x.janet` 最後」，但範例檔其實都有解答 — 補上同一句 — [實測]
- [低][錯誤] `course/4-3-JSON.md:7` — 「跟 struct 幾乎一模一樣，只差鍵的寫法」漏了 JSON 鍵只能是字串：`(json/encode {1 2})` 報 `object key must be a byte sequence`，數字或 tuple 當鍵（3-3 剛教的棋盤）encode 就炸 — 加一句「鍵只能是字串或 keyword」 — [實測]
- [低][範例] `course/4-1-字串與-buffer.md:103` — 只說「要比內容先 `(string b)`」，3-3 剛教的 `deep=` 對 buffer 也比內容（`(deep= @"ab" @"ab")` 為 true），順手提一句可以把兩課接起來 — 加半句「或用 `deep=`」 — [實測]
- [低][文風] `course/3-1-四個容器.md:101` — `(keys @{:a 1 :b 2 :c 3})` 「印出來是 `@[:b :a :c]`」是這個版本的 hash 順序，寫成定論下次 Janet 換版就變成錯的 — 改「例如這次跑出來是…」，重點放「不是你寫的順序」 — [實測]
- [低][文風] `course/3-1-四個容器.md:93` — 錯誤訊息引成 `expected array, got <tuple 0x...>`，實際是 `bad slot #0, expected array, got <tuple 0x...>`（範例檔 42 行是對的）— 課文補上 `bad slot #0`，讓讀者對照得上 — [實測]

## 沒來得及看的

- 無（六篇課文、六支範例檔都讀完並實跑；連結全部存在，檔案大小都在 150 行／8192 bytes 內，沒有簡體用字與 AI 味套話）。
