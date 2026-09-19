# 46f · 模組、jpm 與標準函式庫

[← 46 從 Python 過來](46-從-Python-過來.md)

`import`、`if __name__`、pip 對 jpm，還有一張「Python 標準函式庫在 Janet 叫什麼」的表。

## import

| Python | Janet |
|---|---|
| `import x` | `(import x)` — 用 `x/f` 呼叫 |
| `import x as y` | `(import x :as y)` |
| `from x import *` | `(import x :prefix "")` — 直接 `(f)` |
| `from . import lib` | `(import ./lib)` |
| `import x.y.z` | `(import x/y/z)` — 路徑用斜線 |

```janet
(import spork/json :as json)
(import ./lib :prefix "")
```

⚠ `import` 只能放在**檔案頂層**，不能寫在函式裡（Python 可以）。
要動態載入得用 `require`／`dofile`。路徑怎麼找的完整規則見 [05e](05e-import-與模組路徑.md)。

⚠ 沒有 `__init__.py`，也沒有「套件」這層概念——一個 `.janet` 檔就是一個模組。

## `if __name__ == "__main__"`

寫一個 `main` 函式就好，Janet 跑腳本時會自動呼叫它，被 `import` 時不會：

```janet
(defn main [& args]
  (printf "args=%j" args))
```

⚠ `args` 的第 0 個是**腳本自己的路徑**（等於 `sys.argv[0]`），真正的參數從第 1 個開始。
`(dyn :args)` 拿得到同一份，`(dyn :executable)` 是 janet 執行檔的路徑。
完整動態變數表見 [40](40-內建動態變數.md)，CLI 參數解析見 [04](04-cli-argparse.md)。

## pip 對 jpm

| Python | Janet |
|---|---|
| `pip install x` | `jpm install x` |
| `requirements.txt` / `pyproject.toml` | `project.janet` 的 `:dependencies` |
| `venv` | `jpm -l`（裝進專案裡的 `jpm_tree/`） |
| `pip install -e .` | `jpm -l install git::file:///絕對路徑` |
| `python -m pytest` | `jpm test`（跑 `test/*.janet`） |
| `python -c "..."` | `janet -e '...'` |
| `python -i` | `janet -r`（跑完進 REPL） |
| `python script.py` | `janet script.janet` |
| `pyinstaller` | `jpm quickbin`（見 [16d](16d-image-與-jpm.md)） |

⚠ 沒有全域安裝與虛擬環境的分裂——`jpm -l` 就是 venv，只是它把東西放在
專案底下的 `jpm_tree/`，要跑起來得帶著它（`jpm -l janet ...`）。細節見 [05d](05d-引用自己的專案.md)。

## 標準函式庫對照

| Python | Janet | 說明 |
|---|---|---|
| `print(x, file=sys.stderr)` | `(eprint x)` | `eprintf` 對應格式化版 |
| `json` | `spork/json` | 見 [03](03-json.md)。⚠ decode 預設給**字串 key**，要 keyword 得傳第二個參數 `true` |
| `re` | PEG，或 `spork/regex` | 見 [14](14-peg.md)。regex 只是 PEG 的糖衣，功能是子集 |
| `subprocess.run` | `os/execute` / `os/spawn` | 見 [11](11-pipeline-signal.md) |
| `os.system` | `os/shell` | ⚠ 回的不是 exit code，見 [39](39-跟作業系統打交道.md) |
| `pathlib` / `os.path` | `spork/path` | `path/join`／`path/ext`／`path/basename` |
| `os.environ` | `(os/getenv "K")` / `(os/setenv ...)` | 見 [12d](12d-os-環境變數.md) |
| `datetime` | `os/date` / `os/mktime` / `os/strftime` | ⚠ 月與日是 **0-based**，見 [24](24-時間與日期.md) |
| `time.time()` | `(os/time)` | Unix 秒 |
| `time.perf_counter()` | `(os/clock)` | |
| `random` | `math/random` / `math/rng` | ⚠ 預設種子固定，每次跑一樣，見 [26](26-隨機數.md) |
| `secrets` | `os/cryptorand` | |
| `threading` | `ev/thread` | 真 OS 執行緒，見 [15](15-ev-channel-net.md) |
| `asyncio` | `ev/spawn` / `ev/sleep` / `ev/chan` | 同上 |
| `queue.Queue` | `(ev/chan n)` | |
| `pickle` | `marshal` / `unmarshal` | 見 [16](16-marshal-與自省.md) |
| `csv` | 沒有內建 | `snippets/csv.janet` |
| `requests` | `spork/http` | 見 [17](17-用-spork-http-打-api.md) |
| `unittest` / `pytest` | `assert` ＋ `jpm test` | 見 [23](23-測試怎麼寫.md) |
| `logging` | 沒有內建 | 自己包 `eprintf` |
| `math` | `math/` | 見 [21](21-數字與位元.md) |
| `statistics` / `numpy` | `spork/math` | 見 [42](42-spork-math.md) |
| `dataclasses` | struct，見 [46e](46e-Python-錯誤與物件.md) | |

```janet
(import spork/path)
(path/join "a" "b" "c.txt")   # => "a/b/c.txt"
(path/ext "x/y.txt")          # => ".txt"
(path/basename "x/y.txt")     # => "y.txt"
```

```janet
(import spork/json)
(json/decode "{\"a\":1}")        # => @{"a" 1}
(json/decode "{\"a\":1}" true)   # => @{:a 1}
```

⚠ Janet 的標準函式庫比 Python 小很多，`spork` 補一部分（全覽見 [27](27-spork-全覽.md)），
剩下的多半得自己寫。好消息是這些東西通常只有十幾行。

## 沒有的東西

`asyncio` 以外的並行模型、型別註記與 mypy、裝飾器語法、運算子多載、
context manager 協定、例外型別階層、set、任意精度整數、內建的 `datetime` 物件。
前三個用巨集補，後面幾個就是接受它。

下一步：回 [46 從 Python 過來](46-從-Python-過來.md) 看整體，
或往 [01b 給 C++ 開發者](01b-給-C++-開發者.md) 看另一種語言背景的對照。
