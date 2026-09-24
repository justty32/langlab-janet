# 核心速查（續 b）· 地雷合輯

[← 回 核心](核心.md)

## ⚠ 地雷合輯

| 症狀 | 原因 / 正解 |
|---|---|
| `(print arr)` 印出 `<array 0x…>` | 用 `(pp arr)` 或 `(printf "%q" arr)`；`print` 不格式化容器。 |
| `(t :a :b)` 想取巢狀 | table 當函式只收 1 個引數，compile error。巢狀用 `(get-in t [:a :b])`，要預設值用 `(get t :a 預設)`。 |
| JSON 解回來 `(d :name)` 拿到 nil | `decode` 沒傳 `true`，key 是字串。傳 `true` 轉 keyword。 |
| argparse `--level 5` 拿到 `"5"` 不能算術 | 取回是字串。用 `scan-number` 或選項加 `:map scan-number`。 |
| 想改集合卻報錯 | 忘了 `@`：不可變 `[]`/`{}` 不能改，要 `@[]`/`@{}`。 |
| `(= "abc" :abc)` 是 false | 跨型別永遠不等。先 `(string x)` 或 `(keyword x)` 統一再比。 |
| fiber 裡 `(dyn :k)` 全是 nil | `fiber/new` 的 env 預設 **nil**，不繼承。要 `(fiber/setenv f (curenv))`。 |
| `os/execute` 給了環境 table 卻沒作用 | 旗標要含 `e`（`:pe`），只寫 `:p` 會安靜忽略那張表。 |
| FFI 拿 `char*` 轉字串炸掉 | `(ffi/read :string (ffi/write :ptr p))`，不是 `(ffi/read :string p)`。 |
