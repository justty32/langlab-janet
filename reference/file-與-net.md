# file ・ 印與讀 ・ 全部 31 個

> ⚠ 半成品（R1 線中止），`net/*` 那半篇尚未動筆，見 [planning](../wf/workflows/planning.md)。

[← reference 索引](README.md)｜`net/*` 那 19 個規劃放 file-與-netb-socket.md（尚未寫）

對應教學：[19 檔案與檔案系統](../docs/19-檔案與檔案系統.md)、
[19b 檔案系統與路徑](../docs/19b-檔案系統與路徑.md)、[20b 資源管理](../docs/20b-資源管理.md)。
低階的 `os/open`／`os/pipe` 在 [os-全表.md](os-全表.md)。

> 對著 `root-env` 逐一核過：`file/*` **9 個**、`stdin`／`stdout`／`stderr` **3 個**、
> 印與讀的家族 **19 個**，共 31 個全收。

## `file/*`（9 個）

| 函式 | 簽名 | 回什麼 |
|------|------|--------|
| `file/open` | `(file/open path &opt mode buffer-size)` | file handle；⚠ **開不起來回 `nil` 不報錯** |
| `file/close` | `(file/close f)` | `nil` |
| `file/read` | `(file/read f what &opt buf)` | buffer；`what` 是 `:all`／`:line`／整數 |
| `file/write` | `(file/write f & bytes)` | 回 f 本身 |
| `file/flush` | `(file/flush f)` | 回 f 本身 |
| `file/seek` | `(file/seek f &opt whence n)` | 回 f 本身（**不是**新位置）|
| `file/tell` | `(file/tell f)` | 目前位移（整數）|
| `file/lines` | `(file/lines file)` | 走訪每一行的 iterator |
| `file/temp` | `(file/temp)` | 匿名暫存檔，**close 時自動刪掉** |

`mode` 是一個 keyword，字母疊著寫：`r` 讀、`w` 寫、`a` 追加；再接 `b` 二進位、
`+` 讀寫並存、`n` **開不起來時改成報錯**（預設是回 `nil`）。

`whence`：`:set` 從頭算、`:cur` 從目前位置算（預設）、`:end` 從結尾算。

```janet
(def f (file/open "/tmp/t.txt" :w))
(file/write f "hello\nworld\n")
(file/tell f)            # => 12
(file/close f)           # => nil

(def g (file/open "/tmp/t.txt" :r))
(file/read g 5)          # => @"hello"
(file/read g :line)      # => @"\n"
(file/tell g)            # => 6
(file/seek g :set 0)
(file/read g :all)       # => @"hello\nworld\n"
(file/close g)

(def h (file/open "/tmp/t.txt"))
(seq [l :in (file/lines h)] (length l))   # => @[6 6]
(file/close h)
```

⚠ **`file/open` 失敗回 `nil`**，下一步才炸在「nil 不是 file」——錯誤訊息離現場很遠。
要立刻知道就加 `n`：`(file/open path :rn)`。

⚠ `file/seek` 回的是**檔案本身**，想知道跳到哪要再問 `file/tell`。

⚠ 開了就要關。配 `defer` 或 `with`：`(with [f (file/open p)] …)`（見 [20b](../docs/20b-資源管理.md)）。

## 三個標準串流

`stdin`／`stdout`／`stderr` 是 `:core/file`，可以直接餵給 `file/*`：
`(file/read stdin :line)` 讀一行、`(file/write stderr "x")` 寫 stderr。

⚠ 別直接用它們印東西——用 `print`／`eprint`，那組會看 `(dyn *out*)`，
測試時才攔得住（`doc-examples` 就是靠這個把輸出吃掉）。

## 印（12 個）

三個維度：**往哪印**、**要不要換行**、**要不要格式化**。

| | 換行 | 不換行 | 換行＋`%` 格式 | 不換行＋`%` 格式 |
|------|------|--------|------|------|
| `(dyn *out* stdout)` | `print` | `prin` | `printf` | `prinf` |
| `(dyn *err* stderr)` | `eprint` | `eprin` | `eprintf` | `eprinf` |
| **明指目標**（第一個參數）| `xprint` | `xprin` | `xprintf` | `xprinf` |

```janet
(prin "a") (prin "b") (print "!")   # 印出 ab!
(printf "%d-%s" 7 "x")              # 印出 7-x
```

`x` 那組的目標可以是 file 也可以是 **buffer**：

```janet
(def b @"")
(xprint b "hi")
b   # => @"hi\n"
```

⚠ `x` 那組**不看動態變數**，所以 `(with-dyns [*out* @""] …)` 攔不住它。
想讓輸出可被重導，就別用 `x` 那組。

格式動詞（`%d` `%s` `%q` `%j` `%v` `%p`…）的完整表在
[字串與-buffer.md](字串與-buffer.md) 的 `string/format` 那節。

| 函式 | 簽名 | 說明 |
|------|------|------|
| `flush` | `(flush)` | 沖掉 `(dyn *out*)`；不是 file 就什麼都不做，回 `nil` |
| `eflush` | `(eflush)` | 同上但對 `(dyn *err*)` |
| `pp` | `(pp x)` | 用 `(dyn *pretty-format* "%q")` 漂亮印到 `(dyn *out*)` |
| `describe` | `(describe x)` | 回**字串**（不印）：`(describe 42)` → `"42"`、`(describe @[1])` → `"<array 0x…>"` |

⚠ `pp` 印 **Janet 表示法**，中文會變 `\xE5\xA3\x9E`（見 [README](README.md) 末節）。

## 讀（3 個）

| 函式 | 簽名 | 說明 |
|------|------|------|
| `slurp` | `(slurp path)` | 整個檔讀進來，自己開自己關；⚠ 回的是 **buffer** 不是 string |
| `spit` | `(spit path contents &opt mode)` | 整串寫進檔，`mode` 給 `:a` 就是追加 |
| `getline` | `(getline &opt prompt buf env)` | 從 stdin 讀一行（**含換行字元**）；給 env 就有補完 |

```janet
(spit "/tmp/t2.txt" "abc")
(slurp "/tmp/t2.txt")     # => @"abc"
```

⚠ `slurp`／`spit` 一次搬整個檔進記憶體，大檔要用 `file/read` 分塊。
⚠ `spit` 預設**覆寫**。想接在後面要明寫 `(spit path s :a)`。
⚠ `getline` 會**擋住**——沒有終端機（管線、測試）時拿不到東西，別寫進自動化腳本。

原子寫檔（先寫暫存再 rename）的做法見 [snippets/file-io.janet](../snippets/file-io.janet)。
