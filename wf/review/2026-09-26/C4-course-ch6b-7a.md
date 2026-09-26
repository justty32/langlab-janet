# C4 course ch6b-7a 審閱

審閱者：fable｜日期 2026-09-26｜範圍：`course/6-3-執行緒巨集與解構.md`、`course/6-3b-執行緒巨集與解構.md`、`course/6-4-match.md`、`course/6-4b-match.md`、`course/7-1-錯誤怎麼丟怎麼接.md`、`course/7-1b-往上丟與回-nil.md`、`course/7-2-資源收尾-defer-with.md`、`course/7-2b-defer-與-with-的坑.md`、`examples/course/6-3.janet`、`6-4.janet`、`7-1.janet`、`7-2.janet`

## 總評
八支課文和四支範例檔全部實跑，範例輸出與課文標註的 `# =>` 全部一致，沒有跑不動的程式碼。最大的問題在 7-2／7-2b：課文把「中途 `break` 也算離開」當成 `defer` 的賣點，但 `defer`／`with` 的 body 其實被包成一個 closure 丟進 fiber 跑，body 裡的 `break` 只會結束 body、不會跳出外面的迴圈，這個真正的坑反而沒教。其次是 7-1b 把「參數個數錯是 compile error」講成通則，實測對 `string/find` 這類 cfunction 是執行期錯誤、`try` 接得到。最值得先修的一件事：把 7-2:44-53 那段 `break` 範例換掉，並在 7-2b 補「body 裡 `break` 跳不出外層迴圈」這個坑。`match` 這邊少了 `@` 前綴（拿變數當常值比）與「已 def 的名字在模式裡仍是綁定」這一條，是使用者點名要看的東西，課文完全沒提。

## 發現
- [高][錯誤] `course/7-2-資源收尾-defer-with.md:9`、`:44-53` — 「中途 `break` 也算離開」誤導：`defer` 展開成 `(fiber/new (fn [] body))`，body 裡的 `break` 只是從那個 fn 返回，不會跳出外層迴圈。實測 `(while (< n 3) (++ n) (defer (print "收尾") (break)) (print "after" n))` 印三次 after；`(each i [1 2 3] (with [r …] (when (= i 2) (break)) (print "i=" i)))` 照樣印 `i=3`。課文範例之所以「看起來對」是因為 `break` 在 `each` 裡、`each` 又在 `defer` 裡，body 只是正常跑完 — 刪掉這段，改成 7-2b 的一個坑：「`defer`／`with` body 裡 `break` 跳不出外層迴圈，要跳就把 `defer` 放在迴圈外或用旗標」 — [實測]
- [中][錯誤] `course/7-1b-往上丟與回-nil.md:53` — 「參數個數錯是 compile error，`try` 沒機會執行」只對編譯期已知的 Janet 函式（`defn` 出來的）成立；`(try (string/find "a") ([e] :caught))` 回 `:caught`，cfunction 的 arity 是執行期錯 — 改寫成「自己 `defn` 的函式少給參數是 compile error；內建 cfunction 則是執行期錯，`try` 接得到」，並各給一行實例 — [實測]
- [中][錯誤] `course/7-2b-defer-與-with-的坑.md:33` — 「回收也不保證關檔」不對：file 的 GC finalizer 會 `fclose`，實測開檔不存 handle、`(gccollect)` 後 `/proc/self/fd` 數量回到基準 — 改成「GC 回收時會關，但你控制不了何時回收，等 GC 關檔等於沒關」，論點不變、說法要準 — [實測]
- [中][範例] `course/6-4-match.md:44` — 規則「裸的名字是綁定」少了最會咬人的推論：**已經 `def` 過的名字放進模式仍是綁定、不是拿它的值來比**。實測 `(def ADD :add) (match [:sub 1 2] [ADD a b] [:matched ADD])` 回 `(:matched :sub)`；要拿變數當常值要寫 `(@ ADD)`，同一例改成 `[(@ ADD) a b]` 就落到 `_` — 在 6-4b 坑區補一條 ⚠ 並介紹 `@` 前綴（使用者點名要看，兩篇完全沒提） — [實測]
- [中][範例] `course/7-2b-defer-與-with-的坑.md`（整篇） — 少一個坑：body 是 closure，裡面 `def` 的名字出了 `defer`／`with` 就不存在；實測 `(with [f (file/temp)] (def x 1)) x` 直接 `unknown symbol x`（且是 compile error，`protect` 包不住）。讀者照 Python `with` 的直覺會踩 — 補一條 ⚠，並點出要把結果帶出來就用 `with` 的回傳值或 `var` — [實測]
- [低][錯誤] `course/7-1b-往上丟與回-nil.md:55` — 「`assert` 就是一般函式呼叫」不對，`assert` 是巨集（`macex1` 展開成 `(do (def _ (= 1 2)) (if _ _ (error "assert failure in (= 1 2)")))`），這也是它能把原始式子印進訊息的原因 — 改「就是一段普通的執行期程式碼（其實是巨集）」 — [實測]
- [低][錯誤] `course/6-4-match.md:74` — 守衛寫成「`(名字 條件)`」太窄；第一格可以是任何模式，`(match [3 1] ([a b] (> a b)) :desc _ :no)` 回 `:desc` — 改成「`(模式 條件)`」並加這一行例子，順便解決 6-4b:74 「先綁再檢查長度」只能用整個值 `t` 的侷限 — [實測]
- [低][範例] `course/6-4b-match.md:32-38` — 「array 也吃」只講值是 array；沒講模式也能寫 `@[a b]`／`@{:a x}`（實測都能對上），也沒講值是 struct 或字串時 tuple 模式一律不中（`indexed?` 先擋） — 各補一行 — [實測]
- [低][結構] `course/7-2-資源收尾-defer-with.md:28`、`course/7-2b-defer-與-with-的坑.md:7` — 同一個「巨集要先看到收尾動作才好包住後面所有東西」理由寫兩次，而且理由站不住：巨集拿得到全部參數，順序純粹是 `[form & body]` 的 `&` 只能放最後 — 兩處合成一句「`defer` 的簽名是 `[收尾 & body]`，可變長度的 body 只能排最後」，留一處即可 — [疑]
- [低][結構] `course/7-1-錯誤怎麼丟怎麼接.md:79`、`course/7-1b-往上丟與回-nil.md:55` — 「Janet 的 `assert` 不會被編譯選項關掉」前後篇各講一次，內容幾乎重複 — 7-1 那句刪掉，留 7-1b 的 ⚠ 版本 — [實測]
- [低][文風] `course/6-4-match.md:9` — 「這種寫法叫模式比對（match；拿一個值去比「形狀」）」括號裡塞的英文是 `match` 不是術語本身（pattern matching），讀者會以為術語就叫 match — 改成「模式比對（pattern matching）」 — [疑]
- [低][文風] `course/6-3-執行緒巨集與解構.md:1`、`:7` — 標題用「執行緒巨集」，第 7 行還得先花一段澄清「跟多執行緒無關」；這是全 repo 的譯名（docs/01c 同），若不想改譯名，至少標題旁加英文 threading macro 讓人對得上原文 — 全 repo 一致改成「穿線巨集（threading macro）」或保留但補英文 — [疑]
- [低][範例] `course/6-4b-match.md:61-63` — 「只檢查列出來的那幾格存不存在」是簡化說法；`macex1` 展開實際是 `(and (indexed? v) (<= 2 (length v)))`，也就是先檢查型別再比長度下限 — 補一句「展開後是 `(<= 模式長度 (length 值))`，所以叫前綴」，讀者用 `macex1` 也能自己驗 — [實測]

## 沒來得及看的
- 無。八支課文、四支範例檔均已通讀並實跑；連結目標（docs/01c、08、09、19、20、20b、32，course/3-2、3-3、5-1、6-1、7-3、10-1、10-4）均存在且內容與課文引用相符。
