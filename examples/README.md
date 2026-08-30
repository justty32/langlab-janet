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
| `spork-tour.janet` | spork 導覽：十四個模組各跑一段（misc／path／base64／utf8／regex／schema／data／date／htmlgen／fmt／zip／randgen／generators／ev-utils） | `janet examples/spork-tour.janet` |
| `native-module/` | 用 C 寫 Janet 原生模組 | `cd examples/native-module && jpm build`（見下） |
| `embed/` | 把 Janet 嵌進 C 程式 | `cd examples/embed`（見下） |
| `llm-http/` | [`../modules/llm-http/`](../modules/llm-http/README.md) 這個模組的八支範例（見下） | `janet examples/llm-http/01-minimal.janet` |

## llm-http

配 [`modules/llm-http/`](../modules/llm-http/README.md) 的一整組範例——**跑起來就是一份教材**。

| 檔 | 主題 | 要後端嗎 |
|----|------|----------|
| `01-minimal.janet` | 最小問答：`endpoint` ＋ `ask` 兩行 | 要 |
| `02-system-prompt.janet` | system prompt 的三種給法（`ask` 第二參數／`with-tools` 的 `:system`／自組 messages） | 要 |
| `03-multi-turn.janet` | 多輪對話：自己維護 `messages` 陣列、歷史怎麼截斷 | 要 |
| `04-tools.janet` | tool loop：自訂工具、多個工具、handler 丟例外時的行為 | 要（且模型要支援 tool calling） |
| `05-vision.janet` | 圖像輸入：content parts 長怎樣、data URI、多張圖 | 要（且模型要吃圖） |
| `06-custom-endpoint.janet` | **自訂 endpoint 的四種寫法**：inline／`define-endpoint`／設定檔／直接指定 `:url` 繞過 proxy | 前半段不用 |
| `07-params.janet` | 請求參數的覆寫與**合併優先序**（`build-payload` 是純函式，印得出最終 payload） | 前半段不用 |
| `08-errors.janet` | 錯誤處理：連不上／名字打錯／設定檔壞掉／模型不吃圖…每種長什麼樣 | **完全不用** |

### 前置條件

`01`–`05` 與 `06`／`07` 的最後一段需要一台 **OpenAI 相容伺服器**，二選一：

```sh
# (a) litellm proxy（四個 endpoint 都配好了；⚠ fastapi<0.119 這個 pin 不能省）
cd <janet-lab 根目錄>
uv run --with 'litellm[proxy]' --with 'fastapi<0.119' \
       litellm --config modules/llm-http/lite.yaml --port 4000

# (b) 只開 LM Studio，走 06 的 ④「直接指定 :url」那條，連 proxy 都不用架
```

- **沒起來也不會噴 stacktrace**：每支都用 `protect` 把例外接下來，
  印一行「連不上 …」加上怎麼把後端起起來的提示。
- ⚠ 位址一律寫 `127.0.0.1` 不要寫 `localhost`（`::1` 陷阱，見 [FINDINGS.md](../FINDINGS.md) 第五節）。
- ⚠ 這些 example **不在 `jpm test` 裡**——測試一律離線，不打網路、不呼叫真模型。

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
