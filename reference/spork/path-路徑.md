# spork/path ・ 路徑

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/path` 處理檔案路徑字串（純字串運算，不碰檔案系統，跟真的存不存在無關）。
共 36 個公開綁定，但其實只有 **12 個函式／值**，各有三份：不帶前綴的預設版、
`posix/` 版、`win32/` 版。⚠ 這台是 Linux，實測後發現**預設版就是 posix 版本身**——
不只是行為一樣，`(= path/join path/posix/join)` 直接回傳 `true`，代表 janet-lab
這台機器上兩者是同一個函式物件（大概是模組載入時依平台把某一份指標指過去）。
要在 Linux 上刻意處理 Windows 風格路徑，就明確呼叫 `path/win32/xxx`；反過來
在 Windows 上想強制處理 POSIX 路徑，呼叫 `path/posix/xxx`。

## 12 個函式／值（以預設版列出，posix/win32 版簽名相同、只差前綴）

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `sep` | `string` | 路徑分隔字元：POSIX 是 `/`、win32 是 `\` |
| `delim` | `string` | PATH 環境變數的分隔字元：POSIX 是 `:`、win32 是 `;` |
| `join` | `(join & els)` | 接起多段路徑 |
| `abspath` | `(abspath path)` | 把相對路徑轉成絕對路徑（相對於目前工作目錄） |
| `abspath?` | `(abspath? path)` | 判斷是不是絕對路徑 |
| `basename` | `(basename path)` | 取檔名（含副檔名，不含目錄） |
| `dirname` | `(dirname path)` | 取目錄部分（含結尾分隔字元） |
| `parent` | `(parent path)` | 取上層目錄（不含結尾分隔字元） |
| `ext` | `(ext path)` | 取副檔名（含 `.`） |
| `parts` | `(parts path)` | 把路徑拆成陣列，每段一個元素 |
| `normalize` | `(normalize path)` | 化簡路徑：去掉 `.`、解掉 `..`、去掉多餘的空區段 |
| `relpath` | `(relpath source target)` | 算出從 `source` 到 `target` 的相對路徑 |

## 實測範例（Linux 上的預設行為＝posix）

```janet
(import spork/path)

path/sep    # => "/"
path/delim  # => ":"

(path/join "a" "b" "c")        # => "a/b/c"
(path/abspath "foo")           # => "/home/lorkhan/repo/langs/janet-lab/foo"   相對於目前工作目錄
(path/abspath? "/tmp")         # => true
(path/abspath? "tmp")          # => false

(path/basename "/a/b/c.txt")   # => "c.txt"
(path/dirname "/a/b/c.txt")    # => "/a/b/"
(path/parent "/a/b/c.txt")     # => "/a/b"
(path/ext "/a/b/c.txt")        # => ".txt"
(path/parts "/a/b/c.txt")      # => @["" "a" "b" "c.txt"]   開頭空字串代表根目錄
(path/normalize "/a/./b/../c") # => "/a/c"
(path/relpath "/a/b" "/a/b/c/d") # => "c/d"
```

## win32 命名空間（在 Linux 上照樣可以直接呼叫，只是處理的是 Windows 風格字串）

```janet
path/win32/sep    # => "\\"     即反斜線 \
path/win32/delim  # => ";"

(path/win32/join "a" "b" "c")            # => "a\\b\\c"
(path/win32/normalize "a\\.\\b\\..\\c")  # => "a\\c"
(path/win32/abspath? "C:\\foo")          # => true
(path/win32/abspath? "foo")             # => false
```

⚠ `path/win32/*` 只是照 Windows 規則做**字串**運算，不代表這台 Linux 真的能拿它產生的路徑去開檔——
要在 Linux 上讀寫檔案還是得用 POSIX 風格路徑（預設 `path/*`）。反之，若程式要**跨平台**明確處理某一種
路徑格式（例如解析一段從 Windows 機器傳來的設定檔路徑字串），才需要指名 `path/win32/xxx`。

## posix 命名空間（在此台機器上跟預設版是同一個函式）

`path/posix/join`、`path/posix/abspath`、`path/posix/abspath?`、`path/posix/basename`、
`path/posix/dirname`、`path/posix/ext`、`path/posix/normalize`、`path/posix/parent`、
`path/posix/parts`、`path/posix/relpath`、`path/posix/sep`、`path/posix/delim`——
簽名、行為跟前面「12 個函式／值」表完全一樣，這裡不重複列。要跨平台明確指名
POSIX 風格（不管執行環境是什麼系統）時才需要打這個前綴。
