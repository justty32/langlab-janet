# aos

這是 aos 檔案協定的 Janet 綁定：資料夾可當函式呼叫，檔案可當一筆 POSIX 指令跑。
呼叫記錄、投遞、結果落點與登記表由 Janet 讀寫；真正讓地往前走的 `exec`、`run`、`daemon` 仍會叫 Python 原型。

## 安裝與測試

在 janet-lab 裡開發時用相對路徑：

```janet
(import ../modules/aos :as aos)
```

裝進 jpm 的模組樹後，改用 `(import aos/init :as aos)`。它需要 Janet 1.41.2、spork、Python 3.11+ 與一份能跑的 `proto/aos.py`。

```sh
cd /home/lorkhan/repo/langs/janet-lab
jpm deps
for t in test/aos-*.janet; do janet "$t" || echo FAIL "$t"; done
janet examples/aos-call.janet
```

`test/aos-util.janet` 是共用定義，成功時不印東西；其餘三支會各印一行「測試通過 ✓」。

## 公開 API

`opts` 都是 table，方括號表示可省略。條款連結指向 aos repo 的正式 spec。

<!-- wf-nav -->

| 函式名 | 參數 | 回什麼 | 對應 spec |
|---|---|---|---|
| `land?` | `x` | 是不是 land table | 01 名詞 |
| `is-land?` | `path` | 路徑有沒有 `.aos/layout.json` | 01 地 |
| `land` | `path` | 含各協定路徑的 land table；不是地就報錯 | 01 地 |
| `root-of` | `land-or-path` | 真實根路徑 | [S-07-10](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `resolve-in` | `land path` | 以地為原點的絕對路徑 | [S-07-54](../../../../simple_tools/aos/wf/workflows/spec/07b-result-path.md) |
| `init-land!` | `path [opts]` | 建好後的 land table | [02 版面](../../../../simple_tools/aos/wf/workflows/spec/02-layout.md) |
| `workspace` | 無 | Janet 綁定合成的呼叫方地 | [S-07-09～13](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `reset-workspace!` | 無 | `nil`；忘掉 workspace 快取，給測試用 | spec 外的測試工具 |
| `call` | `land [args] [opts]` | 結果字串、JSON table、`nil`，或報錯 | [S-07-02～22、77](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `fn` / `land-fn` | `land [opts]` | 一支會叫 `call` 的 Janet 函式 | [07 同步呼叫](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `call-async` | `land [args] [opts]` | handle；沒 daemon 就寫 `no_daemon` 後報錯 | [S-07-06、27、28](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `handle?` | `x` | 是不是 async handle | [S-07-27](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `status` | `handle` | `:pending`、`:done` 或 `:failed` | [S-07-14](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `await` / `await-result` | `handle [max-ms]` | 結果；失敗或逾時就報錯 | [S-07-07、22](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `inst` | `spec` | 指令 id、結束碼、三條流與結果檔路徑 | [04 指令](../../../../simple_tools/aos/wf/workflows/spec/04-inst-format.md) |
| `exec-file` | `path & argv [opts]` | 同 `inst` | [S-04-01、04](../../../../simple_tools/aos/wf/workflows/spec/04-inst-format.md) |
| `delivery` | `kind from [extra]` | 投遞物 table | [S-07-38](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `deliver!` | `land object` | 收件匣內的正式檔路徑 | [S-07-33～44、53](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `mail!` | `land subject body [from]` | 投遞檔路徑 | [S-07-45](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `proto-path` | 無 | `AOS_PROTO` 或內建原型路徑 | 綁定層 |
| `aos-run` | `argv [opts]` | `@{:out :err :code}` | [06、08 的外部進入點](../../../../simple_tools/aos/wf/workflows/spec/06-exec-and-run.md) |
| `aos-json` | `argv [opts]` | 解過 JSON 的 table，另加 `:exit-code`、`:stderr` | 綁定層 |
| `run-land` | `land [opts]` | `aos run --until idle` 報告 | [S-06-16、17](../../../../simple_tools/aos/wf/workflows/spec/06b-run-rules.md) |
| `exec-once` | `land [opts]` | `aos exec` 這一格的報告 | [S-06-01](../../../../simple_tools/aos/wf/workflows/spec/06-exec-and-run.md) |
| `daemon` | `:start｜:stop｜:ls [opts]` | 原型子行程報告 | [08 daemon](../../../../simple_tools/aos/wf/workflows/spec/08-daemon.md) |
| `daemon-alive?` | 無 | 登記表的 daemon pid 還在不在 | [S-07-28](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `status-path` / `usage-path` | `result` | 兩個保留旁路徑 | [S-07-15、59、72](../../../../simple_tools/aos/wf/workflows/spec/07b-result-path.md) |
| `triple` | `result` | `[:pending｜:done｜:failed status-or-nil]` | [S-07-14、20、69](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `alloc-result` | `caller opts id` | 檢查過的絕對落點 | [S-07-54～61](../../../../simple_tools/aos/wf/workflows/spec/07b-result-path.md) |
| `call-record!` | `caller child mode result args id` | 呼叫記錄 table，並寫進 `.aos/calls/` | [S-07-09～13](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `rearm!` | `land` | 倒帶後的 land table | spec 沒有重跑已 done 地的動作 |
| `decode-out` / `decode-json` | `result opts` / `string` | 字串或 JSON table | [S-07-14](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `now-iso` / `new-id` / `hex-id?` | 無 / 無 / `x` | UTC 時間、32 hex id、id 是否合格 | [S-07-35、38](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `ensure-dir` / `exists?` | `path` | 原路徑 / 布林 | [S-04-11](../../../../simple_tools/aos/wf/workflows/spec/04-inst-format.md) |
| `atomic-write` / `write-json` | `path value` | 寫好的路徑 | [S-07-66](../../../../simple_tools/aos/wf/workflows/spec/07b-result-path.md) |
| `read-json` / `denull` | `path [default]` / `value` | JSON 值 / 把 JSON null 變 `nil` | 綁定層 |
| `string-args` | `args` | 字串鍵值 table；壞鍵名就報錯 | [S-07-13](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `pid-alive?` | `pid` | Linux `/proc/<pid>` 還在不在 | [S-07-28](../../../../simple_tools/aos/wf/workflows/spec/07-call-and-delivery.md) |
| `lock-acquire` / `lock-release` / `with-lock` | `lock [wait-ms]`、`lock`、`lock & body` | 鎖路徑 / `nil` / body 的值 | [S-08-21](../../../../simple_tools/aos/wf/workflows/spec/08-daemon.md) |

## 環境變數

| 名字 | 做什麼 | 預設 |
|---|---|---|
| `AOS_PROTO` | 指到要呼叫的 `proto/aos.py` | 這台機器的 `/home/lorkhan/repo/simple_tools/aos/proto/aos.py` |
| `AOS_HOME` | aos 的家；登記表與 daemon 狀態在 `$AOS_HOME/.aos/` | `HOME` |

測試與範例會把 `AOS_HOME` 切到暫存資料夾，不會碰真正的 `~/.aos/`。

## 最短範例

下面從 [`examples/aos-call.janet`](../../examples/aos-call.janet) 節錄：

```janet
(import ../modules/aos :as aos)
(def r (aos/exec-file "/bin/sh" "-c" "echo 我是一筆指令; exit 3"))
(printf "結束碼 => %q" (r :code))
(prin (r :out))
```

## 已知限制

- 這是綁定，不是 aos 執行引擎。`inst`、同步呼叫與 daemon 操作分別要 shell 出去叫原型的 `exec`、`run`、`daemon`。
- Janet 1.41.2 沒有檔案與資料夾 `fsync`；目前只做 `file/flush → rename`，斷電保證還沒有達到 S-07-33、S-07-66、S-08-22。
- Janet 行程不是一塊 aos 地，所以綁定會在暫存目錄合成 workspace，並用 `tick:0`、`series:"janet"`、`step:"call"` 補滿呼叫記錄。
- 原型要從登記表頂層的 `result`、`args` 重建 async 子行程環境；正式 registry schema 只認 `ext.result`。目前兩份都寫，所以能跑原型，但整份 registry 還不會過 schema。
- 結果落點的父資料夾必須先存在，綁定才能用 `realpath` 防止 symlink 把落點帶出父地。
- 鎖與 pid 判活用了 POSIX hard link 與 Linux `/proc`；這份綁定目前只驗過 Linux。

更完整的裂縫與繞法見 aos spec 附件的 [`janet-binding-findings.md`](../../../../simple_tools/aos/wf/workflows/spec/notes/janet-binding-findings.md)。
