# examples · 可跑的範例

**教學的附件**——配合 `docs/` 某一篇把觀念跑一遍。想找「我要做 X，抄哪段」請看
[`snippets/`](../snippets/README.md)。每支都獨立、都實測過。

| 檔 | 主題 | 跑法 |
|----|------|------|
| `peg-demo.janet` | PEG：組合子、捕獲、具名文法、遞迴、CSV 切割 | `janet examples/peg-demo.janet` |
| `ffi-demo.janet` | C FFI（不編譯，直呼共享庫） | `janet examples/ffi-demo.janet` |
| `ffi-pointers.janet` | FFI 進階：型別大小 / struct / out 參數 / malloc / `char*` | `janet examples/ffi-pointers.janet` |
| `env-introspect.janet` | 列出 env 裡的綁定、查 symbol 型別、切換 env、OS 環境變數 | `janet examples/env-introspect.janet` |
| `subcommands.janet` | git 風格子命令 dispatcher | `janet examples/subcommands.janet add https://x.git -n libs` |
| `fibers.janet` | fiber / generator / 錯誤處理 / ev | `janet examples/fibers.janet` |
| `pipeline.janet` | 子行程 / 管線 / 信號 | `janet examples/pipeline.janet` |
| `testing-demo.janet` | 測試怎麼寫：`assert` 的回傳值、失敗訊息、`deep=`、驗證錯誤路徑 | `janet examples/testing-demo.janet` |
| `time-demo.janet` | 時間與日期：`strftime`、⚠ 0-based 的月與日、日期算術、三種 `os/clock` | `janet examples/time-demo.janet` |
| `seq-tools.janet` | 序列工具：回傳型別實測、原地 vs 新的、`partition` 兩個陷阱、三個推導 | `janet examples/seq-tools.janet` |
| `random-demo.janet` | 隨機數：同種子同結果、擲骰分布、洗牌均勻性驗證、`os/cryptorand` | `janet examples/random-demo.janet` |
| `match-demo.janet` | 模式比對：迷你運算式求值器、字典子集比對、⚠ tuple 前綴比對的坑、`when-let` 短路 | `janet examples/match-demo.janet` |
| `loop-tour.janet` | `loop` 全部 verb 與條件詞各跑一遍、⚠ `:range` 負步長給空的、`:before`/`:after` 的真實順序 | `janet examples/loop-tour.janet` |
| `fn-params.janet` | 五種參數形式、用 `compile` 示範編譯期 arity 錯、⚠ 迴圈裡建閉包 `@[3 3 3]` vs `@[0 1 2]` | `janet examples/fn-params.janet` |
| `error-anatomy.janet` | 三類錯誤各造一個來看、⚠ 尾呼叫吃掉的那層、「呼叫 nil」的怪訊息、`trace` | `janet examples/error-anatomy.janet` |
| `copy-freeze.janet` | 淺拷貝實測、`freeze`/`thaw` 的型別轉換、⚠ 用計數器證明 `prewalk` 會重入自己的產物、字典日常 | `janet examples/copy-freeze.janet` |
| `sorting.janet` | 四個排序函式、⚠ `compare` 當比較器的真實錯誤、不穩定性實證、跨型別順序、中文按 byte 排 | `janet examples/sorting.janet` |
| `bench.janet` | **在你自己的機器上重跑 docs/37 的每個數字**（約 1～2 秒）；附 `disasm` 證明不可變字面值是常數 | `janet examples/bench.janet` |
| `types.janet` | 19 種型別各造一個問 `type`、傘狀判斷函式罩住誰的對照、⚠ `int?`/`nat?` 的 32-bit 真相、轉換表 | `janet examples/types.janet` |
| `os-tour.janet` | 平台偵測、⚠ `os/shell` 的 wait status 對照表、`os/isatty`（**用 `\| cat` 再跑一次看差別**）、權限與檔案操作 | `janet examples/os-tour.janet` |
| `dyn-vars.janet` | `*out*` 其實就是 `:out`、打錯名字被編譯器擋下、把 `print` 導進 buffer、`module/paths` 長什麼樣、`defdyn` | `janet examples/dyn-vars.janet 引數A 引數B` |
| `prototypes.janet` | Janet 版的「類別」：原型鏈＝vtable、三個陷阱（⚠ 共用可變預設值那個做成看得見的實驗）、`with` ＋ `:close` | `janet examples/prototypes.janet` |
| `errors-raii.janet` | `try`／`protect`／`errorf`、`defer` 的三種離開路徑、⚠ **`with` 在 body 拋錯時照樣收尾**、巢狀 `defer` 是 LIFO | `janet examples/errors-raii.janet` |
| `macros.janet` | 每個巨集都印出 `macex1` 展開、⚠ **不用 `with-syms` 會展成 `(let [tmp tmp] …)` 然後爆**、`;` 是 splice 不是註解 | `janet examples/macros.janet` |
| `data-structures.janet` | 四個容器與 `@` 的差別、⚠ 負索引不能直接用、`=` 對 array 比身分、忘了寫 `self` 的真實錯誤 | `janet examples/data-structures.janet` |
| `numbers.janet` | 四種除法對正負數排成表、⚠ **`(blshift 1 32)` 繞回 `1`**、字面值就存不住 2^53+1、`-nan`、負零 | `janet examples/numbers.janet` |
| `spork-tour.janet` | spork 導覽：十四個模組各跑一段（misc／path／base64／utf8／regex／schema／data／date／htmlgen／fmt／zip／randgen／generators／ev-utils） | `janet examples/spork-tour.janet` |
| `native-module/` | 用 C 寫 Janet 原生模組 | `cd examples/native-module && jpm build`（見下） |
| `embed/` | 把 Janet 嵌進 C 程式 | `cd examples/embed`（見下） |
| `llm-http/` | 打 LLM 的八支範例，另成一頁 → [`llm-http/README.md`](llm-http/README.md) | `janet examples/llm-http/01-minimal.janet` |

## llm-http（八支，另成一頁）

配 [`modules/llm-http/`](../modules/llm-http/README.md) 的一整組範例——**跑起來就是一份教材**，
從兩行問答一路到多輪 tool loop 與圖像輸入。清單、前置條件與怎麼把後端起起來
→ **[`examples/llm-http/README.md`](llm-http/README.md)**。

> ⚠ 這八支**不在 `jpm test` 裡**——測試一律離線，不打網路、不呼叫真模型。

## native-module

```sh
cd examples/native-module
jpm build                       # 編出 build/greet.so
JANET_PATH=$PWD/build janet -e '(import greet) (print (greet/add 3 4) (greet/hello "Janet"))'
```

## embed

```sh
cd examples/embed
cc embed.c -I$HOME/.local/include/janet $HOME/.local/lib/libjanet.a \
   -lm -ldl -lpthread -lrt -rdynamic -o embed
./embed
```

對應教學：spork 導覽在 [docs/27](../docs/27-spork-全覽.md)～[30](../docs/30-spork-並行與服務.md)，
測試在 [docs/23](../docs/23-測試怎麼寫.md)，時間在 [docs/24](../docs/24-時間與日期.md)，
序列工具在 [docs/25](../docs/25-序列工具.md)，隨機數在 [docs/26](../docs/26-隨機數.md)，
FFI / native / embed 都在 [docs/10-c-互通.md](../docs/10-c-互通.md)，
fiber 在 [docs/09-fiber.md](../docs/09-fiber.md)，子命令在 [docs/04-cli-argparse.md](../docs/04-cli-argparse.md)，
env 在 [docs/12-env-環境與動態變數.md](../docs/12-env-環境與動態變數.md)，
PEG 在 [docs/14-peg.md](../docs/14-peg.md)。
`llm-http/` 那組對應的是 [modules/llm-http/README.md](../modules/llm-http/README.md)
與 [FINDINGS.md](../FINDINGS.md)（架構為什麼這樣選、環境有哪些雷）。
