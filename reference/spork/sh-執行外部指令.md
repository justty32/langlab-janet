# spork/sh、spork/sh-dsl ・ 執行外部指令

[← spork 索引](README.md)｜[← reference 索引](../README.md)

這份收 `spork/sh`（19 個）＋ `spork/sh-dsl`（7 個）共 26 個綁定：外部指令執行的便利包裝、
跨平台檔案系統操作、以及一套「像 shell 一樣寫」的巨集 DSL。教學 docs/11-pipeline-signal.md
已經講過內建 `os/execute`／`os/spawn` 這套底層機制，這裡先講**跟那套的差異**，再窮舉全部函式。

## ⚠ spork/sh／sh-dsl 跟內建 os/execute／os/spawn 的差別

**`os/execute`／`os/spawn` 是底層機制**：你要自己組指令陣列（`["git" "status"]`）、自己管旗標
（`:p` 用 PATH、`:x` 非零就報錯）、要抓輸出就得自己開 `:pipe`、自己 `:read`、自己 `os/proc-wait`。
好處是完全掌控，適合要精細控制重導、非同步、fiber 並行的場景。

**`spork/sh` 是包了一層的懶人包**：`exec-slurp` 一行抵掉「spawn + pipe + read + wait + trim + 錯誤處理」
一整串內建操作；不用自己拼指令陣列，直接 `(sh/exec-slurp "git" "status")`。除此之外，`spork/sh`
還有一大塊**跟行程執行完全無關**的東西——跨平台的檔案系統工具（`copy`／`rm`／`create-dirs`／
`which`／`exists?`…），這些是 Janet 內建 `os/*` 沒有直接提供、要自己組合好幾個函式才能做到的。

**`spork/sh-dsl` 是更進一步的巨集語法糖**：用 `$`／`$<`／`$?` 這幾個巨集寫起來很像真的在寫 shell
腳本，甚至支援 `|` 管線語法（`($< echo hi | tr a-z A-Z)`），這是內建 `os/execute`／`os/spawn`
完全沒有的——要用內建那套做管線，得自己手動接兩個 `os/spawn` 的 in/out stream（docs/11 有範例）。

簡單說：**要精細控制** → 內建 `os/execute`／`os/spawn`；**只想跑指令拿結果** →
`spork/sh` 的 `exec-slurp`／`exec`；**想用管線語法快速寫小腳本** → `spork/sh-dsl`。

## spork/sh：執行指令

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `exec` | `(exec & args)` | 執行指令，回傳 exit code（不管內容） |
| `exec-fail` | `(exec-fail & args)` | 同 `exec`，但非零 exit code 就丟 error |
| `exec-slurp` | `(exec-slurp & args)` | 執行指令，非零就丟 error；成功則回傳去頭尾空白的 stdout |
| `exec-slurp-all` | `(exec-slurp-all & args)` | 同 `exec-slurp`，但回傳 `{:out :err :status}` 三個都要 |
| `which` | `(which name &opt paths)` | 在 PATH（或指定 `paths`）裡找 `name` 執行檔的完整路徑，找不到回 `nil` |
| `split` | `(split s)` | 把一行字串拆成「shell 風格」的 token 陣列（懂引號） |
| `escape` | `(escape & args)` | 把多個字串各自加上正確的 shell 引號後接起來 |
| `devnull` | `(devnull)` | 回傳一個開向 `/dev/null`（或對應系統版本）的 stream，用來丟棄輸出 |
| `self-exe` | `(self-exe)` | 目前這個 janet 執行檔本身的路徑 |

## spork/sh：檔案系統操作

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `exists?` | `(exists? path)` | 路徑存不存在 |
| `copy` | `(copy src dest)` | 複製檔案或整個目錄樹 |
| `copy-file` | `(copy-file src-path dst-path)` | 只複製單一檔案 |
| `create-dirs` | `(create-dirs dir-path)` | 建立目錄（含所有必要的中間目錄，類似 `mkdir -p`） |
| `create-dirs-to` | `(create-dirs-to dir-path)` | 建到「這個檔案路徑的父目錄」為止（自己不建 `dir-path` 本身） |
| `make-new-file` | `(make-new-file file-path &opt mode)` | 建一個空檔案，可指定權限 mode |
| `rm` | `(rm path)` | 刪除檔案或整個目錄樹 |
| `rm-readonly` | `(rm-readonly path)` | 同 `rm`，但連唯讀（read-only）的檔案／目錄都刪得掉 |
| `list-all-files` | `(list-all-files dir &opt into)` | 遞迴列出目錄下所有檔案的完整路徑 |
| `scan-directory` | `(scan-directory dir func)` | 遞迴走訪目錄，每個檔案呼叫一次 `func` |

## spork/sh-dsl：shell 風格巨集

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `$` | `($ & cmd)` | 跑一段管線，回傳每個指令的 exit code（一般看最後一個） |
| `$<` | `($< & cmd)` | 跑管線，回傳最後一個指令的 stdout（buffer） |
| `$<_` | `($<_ & cmd)` | 同 `$<`，但去掉結尾最後一個換行字元 |
| `$?` | `($? & cmd)` | 跑管線，最後一個指令成功回 `true`、失敗回 `false` |
| `run-pipeline` | `(run-pipeline pipeline &named capture-output)` | 這幾個巨集底層呼叫的函式版本，吃的是已經展開好的 pipeline 物件 |
| `*errexit*` | 動態變數 keyword | 設了之後，`$`／`$<`／`$<_` 遇到非零 exit code 就直接丟 error（像 `set -e`） |
| `*pipefail*` | 動態變數 keyword | 設了之後，管線的回傳值是「最後一個非零的 exit code」而不是預設的「最右邊那個」（像 `set -o pipefail`） |

## 實測範例

```janet
(import spork/sh)

(sh/which "ls")                 # => "/usr/bin/ls"
(sh/exists? "/etc/passwd")      # => true
(sh/exists? "/no/such/thing")   # => false

(sh/exec-slurp "echo" "hello")  # => "hello"     自動去頭尾空白
(sh/exec "echo" "hi-exec")      # 印出 hi-exec，回傳 0（exit code）

(try (sh/exec-fail "false") ([e] (print "caught: " e)))
# => caught: command failed with non-zero exit code 1

(sh/split "foo \"bar baz\" 'qux'")  # => @["foo" "bar baz" "qux"]
(sh/escape "a b" "c")               # => "'a b' 'c'"
```

⚠ `exec` / `exec-slurp` 這些都是**變數參數版本**（`(sh/exec "echo" "hi")`），不是吃一個陣列——
跟 `os/execute` 要傳 `["echo" "hi"]` 一整個 tuple 不一樣，別搞混。

檔案系統操作（在暫存目錄示範，實測於這台機器）：

```janet
(sh/create-dirs-to "/tmp/x/a/b/c.txt")
(sh/make-new-file "/tmp/x/a/b/c.txt")
(sh/copy-file "/tmp/x/a/b/c.txt" "/tmp/x/a/b/d.txt")
(sh/list-all-files "/tmp/x/a/b")
# => @[".../c.txt" ".../d.txt"]

(sh/copy "/tmp/x/a" "/tmp/x/a2")     # 整個目錄樹複製
(sh/rm "/tmp/x")                     # 整個刪掉，目錄樹也一起
(sh/exists? "/tmp/x")                # => false
```

sh-dsl（`$` 系列會把 stdout 原樣轉發到終端；`$<`／`$<_` 是**攔截**下來不轉發）：

```janet
(import spork/sh-dsl :prefix "")

($ echo hello)     # 印出 hello，回傳 0
($< echo hello)    # 不印，回傳 @"hello\n"
($<_ echo "hello") # 不印，回傳 @"hello"        去掉了結尾換行
($? echo hello)    # 印出 hello，回傳 true

($< echo "hello world" | tr "a-z" "A-Z")   # => @"HELLO WORLD\n"   支援 | 接管線

(setdyn *errexit* true)
(try ($ false) ([e] (print "caught: " e)))
# => caught: non-zero exit code 1
```

⚠ `$<_` 只去掉**最後一個**換行字元（像 shell 的指令替換 `` `cmd` ``），不是整體去頭尾空白——
`($<_ echo "  hello  ")` 會得到 `@"  hello  "`，中間跟開頭的空白都還在，只有結尾的換行沒了。
