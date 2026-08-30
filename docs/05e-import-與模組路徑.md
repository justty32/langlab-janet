# 05e · import 與模組路徑

`import` 看起來只是一行，但 Janet 的路徑規則跟多數語言不一樣，寫錯的錯誤訊息又很不直覺。
這篇把**通用規則**講完；跨專案引用自己的另一個 repo 見
[05d 引用自己的專案](05d-引用自己的專案.md)，本 repo 兩個模組的實際用法見
[`modules/README.md`](../modules/README.md)。

## 五條規則先記住

**① 相對路徑是相對「寫這行 import 的那支檔案」，不是相對你在哪個目錄下指令。**
這是 Janet 跟很多語言最不一樣的一點。同一行 `(import ../modules/llm-http/init)`，
放在 `test/x.janet` 裡是對的，複製到 `bin/x.janet` 裡也是對的（兩者都在根目錄下一層），
但複製到根目錄的檔案裡就錯了——跟你 `cd` 到哪毫無關係。

**② 相對路徑一定要有 `./` 或 `../` 開頭。** 沒前綴的裸名字（`(import spork/json)`）走
**系統模組路徑**（`(dyn :syspath)` 與 `module/paths`），不會當成你旁邊的檔案。

**③ 絕對路徑不能用。** `(import /home/你/…)` 開頭的 `/` 會被吃掉。真的需要絕對路徑時用
`(dofile "/絕對/路徑.janet")`（但那會繞過模組快取，每次重跑）。

**④ `~` 不是家目錄，是 quasiquote。** `~/repo/x` 被讀成 `(quasiquote /repo/x)` 一個
**tuple**，錯誤訊息長成 `could not find module <tuple 0x...>`——看到 `<tuple>` 就是它。

**⑤ 不要帶 `.janet` 副檔名。** 那是模組名不是檔名，Janet 自己會接 `.janet`／`.so` 去找。

> 更完整的 import 語意（快取、`:prefix`、`merge-module` 挑名字、`dofile` 的差別）
> 見 [`../snippets/import-files/main.janet`](../snippets/import-files/main.janet)，那支跑起來就是一份教材。

## `:as` 跟直接 import 的差別

```janet
(import ../modules/llm-http/init)              # → 前綴是 init/…   ← 通常不是你要的
(import ../modules/llm-http/init :as llm)      # → 前綴是 llm/…     ← 建議這樣
(import ../modules/llm-http/init :prefix "")   # → 不加前綴，ask、endpoint 直接可用
```

**前綴預設取路徑最後一段**，而這些模組的門面檔都叫 `init.janet`，所以不給 `:as`
會變成一堆 `init/ask`、`init/endpoint`——很難讀。**一律給 `:as`。**

## ⚠ import 一定要放在**頂層**

`import` 是**編譯期**就要生效的，塞進函式裡等執行才跑，那時候用到它的程式碼早就編譯失敗了。

```janet
(defn 壞例子 []
  (import ../modules/llm-http/init :as llm)    # ✗ 不要這樣
  (llm/ask …))
```

> 上面那些 `../modules/…` 的路徑，是**寫在 `test/` 或 `bin/` 底下的檔案裡**才成立的——
> 這正是規則 ① 的意思：路徑相對的是**寫這行的那支檔案**，不是你在哪裡下指令。

下一步：[06-編輯器與-REPL.md](06-編輯器與-REPL.md)。
