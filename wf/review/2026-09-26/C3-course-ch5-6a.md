# C3 course ch5–6a 審閱

審閱者：fable｜日期 2026-09-26｜範圍：`course/5-1-條件.md`、`course/5-2-迴圈.md`、`course/5-3-沒有-return.md`、`course/6-1-函式與參數.md`、`course/6-1b-函式與參數.md`、`course/6-2-閉包與高階函式.md`、`course/6-2b-閉包與高階函式.md`、`examples/course/5-1.janet`、`examples/course/5-2.janet`、`examples/course/5-3.janet`、`examples/course/6-1.janet`、`examples/course/6-2.janet`

## 總評

七支課文的說法與範例輸出幾乎全部與 Janet 1.41.2 實測相符：五支 example 檔全部跑過，輸出與課文 `# =>` 一致；truthiness、`loop` 動詞、`break` 在函式層等於 return、迴圈裡 `break` 帶不出值、`label`／`return` 是函式與 fiber 實作、閉包抓變數本身、while 裡建閉包的坑，都經實測確認正確。沒有發現「讀者照做會錯」的高嚴重度錯誤。
最值得先修的一件事：5-3 標題與開頭說「Janet 沒有 `return`」，同一支檔後半卻教 `(return 名字 值)`，讀者先被告知沒有、再看到有，容易混亂；建議開頭改成「沒有 C 那種 `return` 敘述，函式層早退用 `break`，跨層跳用 `label` 加 `return` 函式」。
其次是 6-1b `&named` 少了一個真實的坑：keyword 打錯字或少給值時完全靜默（實測 `(連線 "h" :prot 80)` 回 `("h" nil nil)` 不報錯），這比它現有的「引數個數是編譯期錯誤」更常踩到。

## 發現

- [中][結構] `course/5-3-沒有-return.md:1`、`:3` — 標題與首段說「Janet 沒有 `return` 這個關鍵字」，但 `:81`–`:92` 教的就是 `return` 函式（`(type return)` 為 `:function`），且 `:29` 已說函式層 `break` 等於 return — 開頭改成「沒有 C 式 `return` 敘述；有 `break`（函式層）與 `label`＋`return`（跨層）」，並在首段就點出這一句 — [實測]
- [中][錯誤] `course/6-1b-函式與參數.md:34` — docstring 範例的輸出寫 `eval on line 1, column 1`，但在 REPL 裡實際是 `repl on line 1, column 1`（`eval` 只在 `janet -e` 下出現），且 2-3 課 `course/2-3-在-REPL-裡自助查.md:35` 已用 `repl on line 1` 並解釋過 — 改成 `repl on line 1, column 1` 與 2-3 一致 — [實測]
- [中][範例] `course/6-1b-函式與參數.md:7`–`:16` — `&named` 少了最常踩的坑：keyword 打錯或少給值都靜默；實測 `(連線 "h" :prot 80)` → `("h" nil nil)`、`(連線 "h" :port)` → `("h" nil nil)`、`(連線 "h" 80)` 也不報錯 — 在坑那節加一條 ⚠「`&named` 的 key 打錯字不會報錯，全部變 `nil`」附這三行實測 — [實測]
- [低][錯誤] `course/6-1b-函式與參數.md:52` vs `:56` — 文字說「錯誤訊息是 `compile error`」，但緊接的 `janet -e` 範例輸出是 `error: <function a> expects at least 1 argument, got 0`（沒有 compile 二字）；`compile error:` 前綴只在跑檔案時出現 — 說明改成「跑檔案時訊息開頭是 `compile error:`，`-e` 下只有 `error:`」或範例改用檔案 — [實測]
- [低][範例] `course/6-1b-函式與參數.md:18`–`:23` — `&keys` 的賣點寫成「原封不動轉手給下一個函式」，卻沒示範怎麼轉手（要 `(inner ;(kvs 其他))`，實測可行） — 補一行轉手範例，否則讀者不知道拿到 struct 後怎麼再傳 — [實測]
- [低][結構] `course/6-1-函式與參數.md:9` — 首段說 `&opt`、`&`、`&named` 三種「下面一種一種來」，但 `&named` 在 6-1b；6-1 本體只有 82 行 3403 bytes，沒有坑與練習，兩檔合併 164 行超標所以拆是必要的，但拆點與首段承諾不合 — 首段改成「這篇講 `&opt` 與 `&`，`&named` 在續篇」；或把 `default` 一節精簡讓 `&named` 併回 6-1 — [疑]
- [低][結構] `course/6-2-閉包與高階函式.md:1`、`:3` — 標題含「閉包」、首段承諾「做出記得自己狀態的小函式」，但整支 6-2 沒有閉包，閉包全在 6-2b — 6-2 改名「高階函式」、6-2b 改名「閉包」，首段承諾對應調整；拆點本身自然 — [疑]
- [低][文風] `course/5-2-迴圈.md:29` — 小標寫「eachp：走 table 的鍵和值」，範例 `{:apple 3 :pear 5}` 卻是 struct（3-1 剛區分過兩者） — 小標改「走 table／struct 的鍵和值」或範例改用 `@{...}` — [實測]
- [低][錯誤] `course/5-1-條件.md:124` — 「`case` 只拿來比 keyword、數字、字串、tuple」漏了 struct、`nil`、`true`／`false` 也是按內容比得中（不可變的都行） — 改成「不可變的值（keyword、數字、字串、tuple、struct…）都行，array／table／buffer 這些可改的不行」 — [實測]
- [低][難懂] `course/6-2-閉包與高階函式.md:83` vs `:96` — 說 `|` 後面接「一個 form（一組括號）」，但 `:96` 的 `|$&` 沒有括號 — 把「一組括號」改成「一個 form，通常是一組括號，也可以是單一符號」 — [實測]
- [低][範例] `course/6-2b-閉包與高階函式.md:82` — 說「`seq`、`loop` 或 `each` 每一圈都開一個新的綁定」，實測正確；但真正的關鍵是「綁定在圈內建立（`def`／`let`／迴圈變數）vs `var` 在圈外」，`while` 內寫 `(def k j)` 也一樣沒事（實測 `@[0 1 2]`） — 一句話點破「差別不在哪種迴圈，在變數是圈內新開的還是圈外那一個」 — [實測]
- [低][結構] `course/5-1-條件.md`、`course/5-2-迴圈.md`、`course/5-3-沒有-return.md`、`course/6-1-函式與參數.md`、`course/6-2-閉包與高階函式.md` — 只有「下一課」沒有「上一課」（全 course 只有 5 支有上一課連結） — 統一補上，或全部拿掉維持一致 — [實測]

## 沒來得及看的
- 沒有；範圍內十二支檔全部讀完並實跑。未逐字比對 `docs/32b-loop-全表.md` 的「八個動詞八個條件詞」計數（5-2:147 的轉述），實測該檔出現 `:range :range-to :down :down-to :in :keys :pairs :iterate :when :while :before :after`，看起來動詞不到八個，需要另外核。
