# D5 docs/10 FFI 與 native 審閱

審閱者：fable｜日期 2026-09-26｜範圍：`docs/10-c-互通.md`、`docs/10b-ffi-型別與指標.md`、`docs/10c-ffi-字串與地雷.md`、`docs/10d-native-與嵌入.md`、`examples/native-module/`、`examples/embed/`、`snippets/pipe-to-child/`

## 總評
四篇的程式碼幾乎全部實測可跑：`ffi/native`/`lookup`/`signature`/`call`/`defbind`、`ffi/write`/`read` 對 struct 的行為、out 參數、struct 傳值、malloc/pointer-buffer、native module（`jpm build` 成功、`greet/add` 回 7）、embed（靜態連結成功、輸出 42）、`pipe-to-child`（`build.sh` 編過、主程式跑完）全部符合文中描述。`JANET_MODULE_ENTRY(JanetTable *env)`、`janet_dostring` 四參數、`declare-native :name :source` 寫法都跟 1.41.2 的 `janet.h` 與 jpm `declare.janet` 一致。
最大的問題在 10c 的「地雷合輯」表：兩條說法跟實際行為相反（拿 `nil` 去 `ffi/call` 是乾淨錯誤不是 segfault；`:size` 回來的 u64 能算術、真正的地雷是 `=` 比對）。最值得先修的一件：10 主篇把 `strlen` 回傳標成 `# => 5`，讀者照做會發現是 `<core/u64 5>` 而且 `(= 5 …)` 為 false，這正是 10c 要講的坑，主篇卻先埋了誤導。

## 發現
- [高][錯誤] `docs/10c-ffi-字串與地雷.md:37` — 「`ffi/call` 直接 segfault，沒有錯誤訊息…拿 nil 去 call 才炸」不對：`(ffi/call nil sig)` 噴 `error: bad slot #0, expected ffi callable pointer type, got nil`，是乾淨的錯誤 — 改成「lookup 回 nil 不報錯，到 call 時才會給 `bad slot #0 … got nil`，所以看到這條訊息先回頭查符號名有沒有打錯」 — [實測]
- [高][錯誤] `docs/10-c-互通.md:33` — `strlen` 例子註 `# => 5`，實際回 `<core/u64 5>`，`(= 5 …)` 是 false — 註解改成 `# => <core/u64 5>`，並加一句「`:size`/`:u64` 回抽象整數，見 10c」 — [實測]
- [中][錯誤] `docs/10c-ffi-字串與地雷.md:38` — 「`:size` 回來的值不能算術」不對：`(+ 1 n)`、`(* n 2)` 都能做（回 `<core/u64>`）；真地雷是 `(= 3 n)` 為 false、`(< n 5)` 也是 false，`compare=` 才 true — 症狀改寫成「`=`/`<` 比對永遠 false、印出來多一層 `<core/u64>`」，正解仍是 `int/to-number` — [實測]
- [中][範例] `docs/10c-ffi-字串與地雷.md:10` — 用了 `libc` 但這篇沒定義（在 10b 才有），複製貼上第一行就 `unknown symbol libc` — 開頭補一行 `(def libc (ffi/native "libc.so.6"))` — [實測]
- [中][錯誤] `docs/10b-ffi-型別與指標.md:33-34` — 「tuple 在 FFI 裡另有含意」沒講是什麼；實際 tuple 就是 struct 的簡寫：`(ffi/size [:int :int])` = 8、`(ffi/write [:int :int] [1 2])` 可用，所以 `[:int 4]` 才會把 `4` 當型別噴 `bad native type 4` — 直接寫「`[...]`（tuple）＝ `ffi/struct` 簡寫，所以 `[:int 4]` 是拿 4 當第二個欄位型別」 — [實測]
- [中][結構] `docs/10-c-互通.md:38` 與 `docs/10c-ffi-字串與地雷.md:42` — 主篇說「寫錯型別會直接 segfault」，10c 說「參數型別對不上 Janet 會先擋」，兩篇打架 — 主篇改成「Janet 只擋值的種類（數字給成字串），大小／順序／回傳型別寫錯才 segfault」 — [實測]
- [中][難懂] `docs/10b-ffi-型別與指標.md:5-8` — 標題「一之二、型別、指標與記憶體（FFI 最難的部分）」跟前一段重複講「FFI 最難的部分」，而且 h2 只有這一個、底下全是 h3，編號「一之二」是拆檔前殘留 — 拿掉 h2 編號，把 h3 升成 h2 — [疑]
- [中][結構] `docs/10c-ffi-字串與地雷.md:5` — h1 下直接 h3，沒有 h2；和 10b 一樣是拆檔殘留 — h3 升 h2 — [疑]
- [低][錯誤] `docs/10-c-互通.md:20` — `# => 1.0`，實際印 `1`；同檔 `:49` 寫 `# => 1`，前後不一 — 統一成 `1` — [實測]
- [低][錯誤] `docs/10b-ffi-型別與指標.md:78-79` — 「`ffi/read` 讀不到」實際是噴 `read out of range` 錯誤，不是靜靜讀不到 — 把錯誤訊息寫出來，讀者才對得上 — [實測]
- [低][範例] `docs/10b-ffi-型別與指標.md:44` — 只講「給了 buffer 就附加在後面」，第四參數 `index` 沒講；`(ffi/write :int 1 buf 0)` 是就地覆寫，`index` 超過長度噴 `index out of bounds` — 補一句 index 是覆寫用的 offset — [實測]
- [低][範例] `docs/10b-ffi-型別與指標.md:97-103` — `ffi/free mem` 之後 `view` 還指著那塊記憶體，沒警告不能再碰 — 加一行「free 後 `view` 是懸空的，別再用」 — [疑]
- [低][文風] `docs/10c-ffi-字串與地雷.md:49` — 「寫 native 模組（下一節）」，native 模組在 10d 是下一篇不是下一節 — 改「下一篇 10d」 — [疑]
- [低][結構] `docs/10d-native-與嵌入.md:90-92` 與 `docs/10-c-互通.md:67-68` — 「可跑範例 ffi-demo / ffi-pointers」在主篇和 10d 結尾各寫一次，10d 講的是 native／embed 卻列 FFI 範例 — 10d 結尾只留 `examples/native-module/`、`examples/embed/` — [疑]
- [低][範例] `docs/10d-native-與嵌入.md:20-24` — native 模組只有 happy path，沒示範型別錯時的行為；實測 `(greet/add "a" 1)` 噴 `bad slot #0, expected number, got "a"` in greet/add，正好說明 `janet_getnumber` 幫你檔了 — 補這一行輸出 — [實測]
- [低][範例] `docs/10d-native-與嵌入.md:41-43` — `jpm build` 產物除了 `greet.so` 還有 `greet.a` 和 `greet.meta.janet`，文中沒提，讀者看到 build/ 五個檔會疑惑 — 加一句「`.a` 是給靜態打包用，可忽略」 — [實測]
- [低][文風] `examples/native-module/src/greet.c:6`、`examples/embed/embed.c:6` — 註解寫「詳解見 docs/10-c-互通.md」，拆檔後詳解在 10d — 改指 `docs/10d-native-與嵌入.md` — [實測]

實測通過、無需修改的部分：`ffi/defbind` 展開成 `ffi/defbind-alias`，`[x :double]` 寫法正確；`ffi/context :lazy true` 對不存在的庫確實延到呼叫才報錯、`:map-symbols` 可用；`ffi/write`/`ffi/read` struct 往返、巢狀 struct 與 `@[:char 4]` 大小、`clock_gettime` out 參數、`div` struct 回傳、`getenv :string`／`:ptr`＋`(ffi/read :string (ffi/write :ptr p))`／`pointer-buffer` 三種取字串法；`(ffi/read :string raw-ptr)` 與回傳 NULL 給 `:string` 兩者確實 segfault（exit 139）；`snippets/pipe-to-child` 以 `- 3 0.1` 與 `cat 2 0.1` 兩組參數都跑完、產物 `child` 已在 `.gitignore`。簡體用字與 AI 套話 grep 皆無命中。

## 沒來得及看的
- 10c 「回呼（callback）」一節的 `ffi/trampoline` 只對照 docstring，沒實跑。
- 10c:40 「Janet buffer realloc 後舊指標失效」沒實測構造出來。
- 10d 嵌入一節沒測 `janet_dostring` 出錯（語法錯）時的回傳值與行為。
- `docs/10-c-互通.md` 開頭表格三種接法的取捨描述沒逐字對照其他篇（11、00）。
