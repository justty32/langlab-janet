# C7 course 第 10 章（fiber／ev／PEG／巨集／原型）審閱

審閱者：fable｜日期 2026-09-26｜範圍：`course/10-1-fiber.md`、`course/10-2-ev-非同步.md`、`course/10-3-PEG.md`、`course/10-4-巨集.md`、`course/10-5-原型與方法.md`、`examples/course/10-*.janet`

## 總評
五支範例檔全部實跑，輸出跟課文貼的一致，沒有跑不動的程式碼。五課都有「這是什麼、為什麼」開場，先給情境再給機制，深入淺出這點有做到。最值得先修的是 10-1 對 signal mask 的說法：課文把 `:y` 講成「平常用不到」，但實測一給 `:e` 遮罩、預設的 yield 攔截就沒了，fiber 裡 `yield` 會直接炸到最外層。其次是 10-2 對 `ev/spawn`／`ev/go` 差別的描述不準，會讓讀者以為 spawn 出來的東西不能 cancel。其餘多是小處。

## 發現
- [高][錯誤] `course/10-1-fiber.md:81` — 說 `:y`「平常用不到，知道有這回事就好」；實測不給遮罩時預設就是攔 yield（`(fiber/new f)` 可 yield、狀態 `:pending`），但寫成 `(fiber/new f :e)` 後 yield 不再被攔，`(yield 1)` 直接往上炸「pending: 1」中止程式 — 改成「不給遮罩＝只攔 yield；一旦自己寫遮罩就要自己把 `:y` 加回去，要同時 yield 又攔 error 寫 `:ye`」 — [實測]
- [中][錯誤] `course/10-2-ev-非同步.md:84` — 說 `ev/go` 跟 `ev/spawn` 的差別是「它回傳那個 fiber，你才有東西可以 `cancel`」；實測 `ev/spawn` 是 macro，展開成 `(ev/go (fn [] ...))`，回傳值同樣是 fiber，`(type (ev/spawn ...))` 是 `:fiber`，一樣能 cancel — 改成「spawn 是 go 的語法糖，差別只是一個吃 body 一個吃函式（或 fiber）；兩者都回傳 fiber」 — [實測]
- [中][難懂] `course/10-1-fiber.md:73` — 「`try`、`protect` 底層都是開一個 fiber 攔 error」只講到 `:e`，沒說 `try` 實際用的遮罩是 `:ie`（含 inherit env），讀者照 L76 自己寫 `:e` 版 try 時會跟上一條的 yield 問題撞在一起 — 加一句 `(macex1 '(try ...))` 的展開結果對照 — [疑]
- [中][錯誤] `course/10-5-原型與方法.md:7` — 說「你在 8-1 已經寫過 `(:read f :line)`、`(:close f)`」；grep `course/8-1*.md`、`course/7-2*.md` 只有 `(file/read f :line)`，沒有任何 `(:read ...)`、`(:close ...)` 寫法 — 改成「8-1 用的 `(file/read f :line)` 也可以寫成 `(:read f :line)`，這課就是解釋這種寫法」或改指到真的出現過的地方 — [實測]
- [中][錯誤] `course/10-3-PEG.md:99` — 說 `'` 引用時 `,scan-number`「會被當成兩個字面的 symbol 塞進結果」；實測結果是 `@[(unquote scan-number)]`，一個 tuple、一個元素，而且沒有報錯的原因是 PEG 的 `/` 收到非函式值時當「常數替換」 — 改寫成「結果變成一個 `(unquote scan-number)` tuple，因為 `/` 後面不是函式時會直接把那個值放進結果」 — [實測]
- [中][範例] `course/10-2-ev-非同步.md:62` — `ev/gather` 只給 happy path，沒說其中一件事拋錯時的行為（會取消其他、錯誤往外丟），這是它跟「開 N 個 spawn 自己收 channel」最實質的差別，也是任務要求區分的三者之一 — 補一行 `(protect (ev/gather ... (error "boom")))` 的實測 — [疑]
- [低][範例] `course/10-4-巨集.md:84` — 全課只講 `with-syms`，沒提 `gensym`；docs/08 與 Janet 官方文件都用 `gensym`，讀者到「想更深」會對不上名字 — 加一句「`with-syms` 就是幫每個名字呼叫 `(gensym)` 的簡寫」並貼一個 `(gensym)` 的輸出 — [疑]
- [低][錯誤] `course/10-4-巨集.md:92` — 錯誤訊息寫 `could not find method :+ for <tuple ...>`；實測完整訊息是 `(macro) could not find method :+ for <tuple 0x...> or :r+ for 2`，開頭的 `(macro)` 正是讀者辨認「炸在展開期」的線索 — 把 `(macro)` 前綴補回去 — [實測]
- [低][錯誤] `course/10-4-巨集.md:79` — 印出 `_00000Z`，實測是 `_000010`；課文有寫「尾巴每次不同」所以不算錯，但鐵律 5 要求貼實測值 — 貼實際跑出來的名字 — [實測]
- [低][結構] `course/10-1-fiber.md:103`、`course/10-2-ev-非同步.md:109`、`course/10-3-PEG.md:117`、`course/10-4-巨集.md:110`、`course/10-5-原型與方法.md:103` — 五課都只有「下一課」沒有「上一課」導航，`course/8-2-目錄與路徑.md`、`course/2-1-把東西存起來.md` 有寫上一課 — 統一補上 — [實測]
- [低][難懂] `course/10-3-PEG.md:9` — 說 `peg/match`「從字串開頭開始比」，沒提第三個參數可以指定起點；L86 的 `peg/find` 回傳位置就是要配這個用 — 補半句「第三個參數是起點索引」 — [實測]
- [低][文風] `course/10-2-ev-非同步.md:88` — 一個 ⚠ 段落塞了說法、原因、實測指令、解法四件事共 5 句，是全章最長的一段 — 把實測指令拆成獨立 code block — [疑]

## 沒來得及看的
- `ev/chan` 預設容量是否真的為 0（10-2:60）、`(ev/go (fn [] (ev/sleep 99)))` 是否真會讓程式等到睡完（10-2:90）：實測指令啟動後被使用者關機中斷，未取得結果。
- 五課簡體用字掃描、`docs/` 對應篇章與 course 是否有矛盾。
