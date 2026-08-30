# snippets · 可貼可改的片段

跟 [`examples/`](../examples/README.md) 的差別：examples 是**教學的附件**（配合 `docs/` 某一篇
把觀念跑一遍）；snippets 是**做事的起點**——「我現在要做 X，抄哪一段」。

每支都獨立、都實測過（Janet 1.41.2），跑法一律在檔頭的註解裡。

> **要一次驗全部**：`for f in snippets/*.janet; do timeout 40 janet "$f" </dev/null >/dev/null 2>&1 || echo "✘ $f"; done`
> ⚠ **`</dev/null` 不能省**——`repl-mode` 與 `stdin-async` 會等 stdin，
> 繼承一個不會關閉的 stdin 就會卡到 timeout，看起來像壞掉其實沒有。
> `every-5s-clock` 本來就是無限迴圈（`Ctrl-C` 結束或帶次數參數），要另外排除。

| 片段 | 做什麼 | 順帶學到 |
|------|--------|----------|
| [`every-5s-clock.janet`](every-5s-clock.janet) | 每 N 秒印一次當前時間 | `os/date` 的 0-based 月/日、`ev/sleep` 不擋其他 fiber |
| [`argv-parse.janet`](argv-parse.janet) | 命令列參數 → `@{}` / `@[]`，手寫版 + argparse 對照 | argparse 不吃 `--key=value`；短旗標要先宣告 |
| [`apply-splice.janet`](apply-splice.janet) | `[1 2 3]` → `(add 1 2 3)`、`{:a 1}` → `(f :a 1)` | `apply` 只能攤最後一個；`;` 攤哪都行但 `{}` 字面不吃 |
| [`utf8-strings.janet`](utf8-strings.janet) | UTF-8：字元數、切片、切割、反轉、對齊 | `length` 是**位元組**數；ASCII 分隔符切割是安全的 |
| [`aligned-table.janet`](aligned-table.janet) | 印**中文也對得齊**的表格（含框線、靠右、截斷） | ★ byte 數 ≠ 字元數 ≠ **顯示寬度**；`rawterm/monowidth` 才是對齊要用的那個 |
| [`term-color.janet`](term-color.janet) | 終端上色與進度條，**接管線時自動退回純文字** | `(os/isatty stdout)` 一行決定；⚠ `printf` 自己會換行（不換行的是 `prinf`） |
| [`retry-timeout.janet`](retry-timeout.janet) | 重試（指數退避＋抖動）與逾時，可指定哪些錯誤才重試 | `ev/with-deadline` 超時丟 `"deadline expired"`；⚠ jitter 別用裸的 `math/random` |
| [`config-load.janet`](config-load.janet) | 設定：預設值 → 檔案 → 環境變數 → 呼叫端，一層層蓋上去再驗形狀 | ★ 設定檔**只 `parse` 不 `eval`**（不然等於讓它執行任意程式碼）；`schema` 要用 `(props …)` |
| [`cli-skeleton.janet`](cli-skeleton.janet) | 一支真工具的**接線**：參數 → 設定 → 日誌 → 做事 → 錯誤 → exit code | ⚠ **argparse 會靜默吃掉單獨的 `-`**；日誌走 stderr、產物走 stdout；部分失敗也要回非 0 |
| [`parallel-batch.janet`](parallel-batch.janet) | 並行跑一批工作：限制同時幾個、**一個失敗不拖垮整批**、每個各自限時 | `ev-utils/pmap` 的第三參數限流且**結果保序**；⚠ 但它一個失敗就整批丟出 |
| [`csv.janet`](csv.janet) | 正確的 CSV 讀寫：引號、欄位內的逗號與**換行**，附 round-trip 測試 | ⚠ `(string/split "," …)` 對 `a,"b,c",d` 會切出四欄；連「一行一筆」都不成立 |
| [`stdin-async.janet`](stdin-async.janet) | 非同步（handler 風格）處理 stdin | 內建 `stdin` 會擋住整個 ev 迴圈，要 `(os/open "/dev/stdin" :r)` |
| [`binary-png/`](binary-png/main.janet) | 純二進位：讀 PNG、走訪 chunk、驗 CRC32 | 檔案格式多是**大端序**，`ffi/read` 照機器序會讀錯 |
| [`http-local/`](http-local/main.janet) | 開 local HTTP server，再用 API 去問它 | handler 要自己 `http/read-body`；連不上是丟例外 |
| [`repl-mode.janet`](repl-mode.janet) | 程式跑完掉進 REPL（可用自己的 env / 沙箱 env） | ★ `(repl)` 預設用**全新 env**，要傳 `(curenv)` 才看得到自己的東西 |
| [`file-io.janet`](file-io.janet) | 開檔寫檔、讀進字串、逐行、二進位、原子寫入 | `slurp` 回的是 **buffer**、`with` 自動關檔、`file/lines` 串流 |
| [`json-and-marshal.janet`](json-and-marshal.janet) | `.json` → hash-map；hash-map → 檔案（JSON / marshal 兩條路） | `decode` 要傳 `true`、marshal 存得下 tuple/struct/**閉包** |
| [`file-info.janet`](file-info.janet) | 查路徑：是檔案還是資料夾、可否執行、修改時間… | `os/stat` 跟隨 symlink，`os/lstat` 不跟隨 |
| [`list-dir.janet`](list-dir.janet) | 列出資料夾所有 entry（可遞迴、可攤平） | `os/dir` 只回名字不回路徑、不存在會 **error** 不是 nil |
| [`symbol-prefix.janet`](symbol-prefix.janet) | 判斷 symbol/keyword/字串是否以 `/` 或 `.` 開頭 | ★ 取位元組要 `(in x 0)`，`(x 0)` 是方法呼叫 |
| [`closures.janet`](closures.janet) | 閉包：工廠、私有狀態、memoize、once、partial | 捕的是**綁定**不是值；閉包可以 marshal |
| [`pipe-to-child/`](pipe-to-child/) | 模仿 shell 管道：餵子程式 stdin、收 stdout、送 EOF | 讀寫要分不同 fiber，否則互相卡死 |
| [`fiber-context/`](fiber-context/) | 模仿 Go 的 `context`：取消 / 逾時 / 傳值 / 階層傳播 | 取消是**合作式**的；計時器會吊住 ev 迴圈 |
| [`import-files/`](import-files/) | 像 C++ `#include` 那樣引用其他 `.janet` | 路徑相對「檔案自己」；`import` 吃快取、`dofile` 不吃 |

## 需要編 C 的

只有 [`pipe-to-child/child.c`](pipe-to-child/child.c)，一個檔、不用 cmake：

```sh
sh snippets/pipe-to-child/build.sh     # 編出 child（產物不進 git）
janet snippets/pipe-to-child/main.janet
```

沒編也能跑——`main.janet` 找不到 `./child` 時會自動改用 `cat` 示範。
這個資料夾只放原始碼和編譯腳本，**編譯產物不留在 repo 裡**。

## 常用參數

```sh
janet snippets/every-5s-clock.janet 1 5      # 每 1 秒、共 5 次
janet snippets/list-dir.janet docs -r        # 遞迴列 docs/
janet snippets/file-info.janet /bin/sh ~     # 查指定路徑
janet snippets/pipe-to-child/main.janet - 3 0.2   # 換次數與間隔（- = 用預設）
janet snippets/argv-parse.janet --name A -v --level=3 f1 f2 -- --raw
janet snippets/utf8-strings.janet "自己的字串"
printf 'a\nb\n' | janet snippets/stdin-async.janet     # 管線餵它
janet snippets/binary-png/main.janet /path/to/some.png
janet snippets/http-local/main.janet serve 8080        # 只當 server
janet snippets/http-local/main.janet get http://example.com/   # 只當 client
janet snippets/repl-mode.janet --sandbox          # 進沙箱 REPL
```

對應教學在 [`docs/`](../docs/README.md)：檔案與行程在 [11](../docs/11-pipeline-signal.md)、
fiber 與 ev 在 [09](../docs/09-fiber.md) 與 [15](../docs/15-ev-channel-net.md)、
模組與 env 在 [12](../docs/12-env-環境與動態變數.md)、
符號在 [13](../docs/13-symbol-keyword-字串.md)、
marshal 在 [16](../docs/16-marshal-與自省.md)、
CLI 參數在 [04](../docs/04-cli-argparse.md)、PEG 在 [14](../docs/14-peg.md)。
