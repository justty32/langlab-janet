# 12d · OS 環境變數

[← 12c dyn](12c-dyn.md)｜回到 [12 env：環境表](12-env-環境與動態變數.md)

⚠ 這跟 [12c 的 `dyn`](12c-dyn.md) **完全無關**，只是名字容易混：
`dyn` 是 Janet fiber 自己的動態綁定，這裡講的是作業系統那個 `PATH`／`HOME`。


```janet
(os/getenv "HOME")                 # => "/home/lorkhan"
(os/getenv "NOPE" "預設值")         # 找不到時的預設
(os/setenv "MY_VAR" "abc")         # 設
(os/setenv "MY_VAR" nil)           # 傳 nil = 刪掉
(os/environ)                       # 全部，回傳 table
```

給子行程指定環境：

```janet
(os/execute ["sh" "-c" "echo $MY_VAR"] :p)                    # 預設：繼承父行程環境
(os/execute ["sh" "-c" "echo $MY_VAR"] :pe {"MY_VAR" "override"})
```

> **★ 坑**：第三個參數（環境 table）**只有加了 `:e` 旗標才生效**。寫成 `:p` 而不是 `:pe`，
> 那張 table 會被安靜忽略、子行程照樣繼承你的環境——不會報錯，只是沒作用。

`:e` 給的是**完整取代**，不是疊加；要疊加自己 `(merge (os/environ) {...})`。同一個
table 還能塞 `:in` `:out` `:err` 做重導向（見 [11](11-pipeline-signal.md)）。

### 影響 Janet 自己的環境變數

| 變數 / 旗標 | 作用 |
|------------|------|
| `JANET_PATH=…` | 換模組根目錄（`(dyn :syspath)`）。裝在非標準位置的模組靠這個找到 |
| `janet -m 路徑` | 同上，命令列版 |
| `JANET_PROFILE=…` | 啟動時先跑的 profile.janet；`janet -R` 停用 |
| `janet -l 模組` | 處理後面參數前先載入某模組 |

> **★ `JANET_PATH` 只吃「一個目錄」，不是 PATH 那種冒號清單。**
> 寫成 `JANET_PATH=/a:/b` 的話，Janet 會老老實實去找 `/a:/b/spork/argparse.so` 這種目錄，
> 然後噴 `could not find module`。要多個搜尋位置得改 `module/paths`，不是塞冒號。
> （這台機器的 shell 就設了冒號清單，所以在這個 shell 直接跑 `jpm test` 會 build fail；
> `env -u JANET_PATH jpm test` 就正常。）

> **★ `-l` 的實際行為**：它只是把模組 `require` 進 `module/cache`（跑過一遍、快取起來），
> **不會幫你建綁定**。`janet -l spork/json -e '(json/encode …)'` 會噴 unknown symbol——
> 還是得在程式裡 `(import spork/json)`。

---

## 速查

| 想幹嘛 | 怎麼寫 |
|--------|--------|
| 拿當前環境表 | `(curenv)` |
| 列所有名字 | `(all-bindings)` / 只本層 `(all-bindings env true)` |
| 列所有動態變數 | `(all-dynamics)` |
| 看某綁定的 meta | `(get (curenv) 'name)` |
| 取某綁定的值 | `((get env 'name) :value)`（var 用 `:ref`） |
| 某 symbol 是什麼 | `(type ((get env 'name) :value))`、`(doc name)` |
| 開新環境 | `(make-env)` |
| 在別的 env 求值 | `fiber/new` + `(fiber/setenv f e)` + `resume` |
| 跑檔案拿它的 env | `(dofile "x.janet")` |
| 併別的 env 進來 | `(merge-module (curenv) e "字首")` |
| 讀 / 寫 OS 環境變數 | `(os/getenv "K")` / `(os/setenv "K" "V")` |
| 給子行程換環境 | `(os/execute args :pe env-table)`（別漏 `e`） |

完整可跑範例：[`examples/env-introspect.janet`](../examples/env-introspect.janet)。

下一步：[13-symbol-keyword-字串.md](13-symbol-keyword-字串.md)。
