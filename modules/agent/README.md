# agent

站在 [`../llm-http/`](../llm-http/README.md) 上面的 agent 層：**工具箱**（預設安全的
sandbox 檔案工具、shell、http-get、算數）＋ **記憶**（截斷不拆散 tool_calls）＋
**agent loop**（`make-agent`／`run`）＋ **trace** ＋ **CLI**。llm-http 只管「打模型」，
本模組管「模型要工具時，工具去哪找、怎麼跑、跑完怎麼記」。

## 十行組一個 agent

```janet
(import ../modules/agent/init :as ag)

(def a (ag/make-agent {:endpoint "local"                    # 見 llm-http 的 endpoint 名字
                        :system "你是一個簡短回答問題的助理。"
                        :tools (ag/default-tools :root ".")  # 只讀：read-file/list-dir/search-files/now/calc/http-get
                        :trace (ag/stderr-tracer)}))         # 每一步印到 stderr；省略就安靜

(def out (ag/run a "這個資料夾有什麼？"))
(print (out :text))
```

可跑範例 → [`../../examples/agent/`](../../examples/agent/README.md)。

## 公開 API 一覽（`(import ../modules/agent/init :as ag)`）

| 檔 | 拿什麼 |
|----|------|
| `agent` | `make-agent`、`run` |
| `registry` | `make-tool`、`deftool`、`tool?`、`register-tool!`、`tool-names`、`tools->specs`、`call-tool` |
| `sandbox` | `make-sandbox`、`resolve-path`、`resolve-existing`、`resolve-for-write`、`display-path` |
| `tools-fs` | `read-file-tool`、`list-dir-tool`、`write-file-tool`、`fs-tools` |
| `tools-search` | `search-files`、`search-files-tool` |
| `tools-shell` | `run-command`、`shell-tool`、`allowed?`、`format-result` |
| `tools-http` | `http-get`、`http-get-tool` |
| `tools-misc` | `calc`、`calc-tool`、`now-string`、`now-tool` |
| `presets` | `default-tools` |
| `memory` | `make-memory`、`append!`、`trim!`、`clear!`、`system-of`、`estimate-tokens` |
| `memory-io` | `save!`、`load` |
| `trace` | `stderr-tracer`、`file-tracer`、`collect-tracer`、`tee-tracer` |
| `cli` | `run`、`agent-opts`（純函式，測試用） |

## 安全預設

* **預設只讀**：`default-tools` 給的是 `read-file`／`list-dir`／`search-files`／`now`／`calc`／`http-get`；
  `write-file` 要 `:write? true`、`run-command` 要 `:shell true` 才會出現。
* **sandbox 擋路徑逃逸**：所有檔案工具先過 `resolve-existing`／`resolve-for-write`——
  `..`、絕對路徑、指到外面的 symlink 都被拒絕（`os/lstat` 不跟 symlink，見 `sandbox.janet` 檔頭）。
* **shell 不經過 shell**：`run-command` 用空白切 argv 直接 `os/spawn`，`;`／`|`／`>` 都只是普通參數；
  真正的保險是 `:allow` 白名單（前綴比對）＋ `:timeout`＋`:max-output`。
* **http-get 只有 `http://`**：`spork/http` 沒有 TLS，`https://` 會在送出前就被擋下並回清楚訊息。
* **calc 不是 eval**：PEG 只認得四則運算與括號，塞程式碼進來只會得到「算式看不懂」。
* **工具 handler 丟例外不會弄掛整條 loop**：`call-tool` 接住例外，回「工具執行失敗：…」字串給模型。

## CLI 用法

```sh
janet modules/agent/main.janet "這個資料夾有什麼？"                  # 直接跑，預設 endpoint local
./build/agent -v "1234 乘 5678 是多少？用工具算"                      # -v 看每一步（jpm build 之後）
./build/agent --allow-write -r /tmp/work "把結果寫進 out.txt"
./build/agent --allow-shell --shell-allow ls --shell-allow "git status" "看一下 git 狀態"
./build/agent --save 對話.json "記住我叫小明"
./build/agent --resume 對話.json "我叫什麼？"
./build/agent -i                                                     # 互動模式，/quit 離開
```

旗標定義在 `cli-flags.janet`；`--help` 看完整清單。stdout 只有答案本文，trace／提示／錯誤一律 stderr。

## 還沒做的

* **沒有真後端整合測試**：`test/agent-*.janet` 全部對著同行程的假後端（`test/agent-fake.janet`）跑，
  離線、不需要金鑰；要驗真的模型會不會照這個形狀呼叫工具，仍要手動 `janet examples/agent/01-quickstart.janet`
  搭配真的 litellm proxy／LM Studio（見 `examples/llm-http/README.md`）。
* **`run-command` 的白名單是前綴比對**，不是真的 shell 語意解析——沒有引號、沒有跳脫；夠用但不精細。
* **`calc` 只有四則運算**，沒有變數、函式、比較運算子。
* **`memory-io` 的存檔格式沒有版本遷移**：目前只有 `:version 1`，還沒遇到要改形狀的情況。
