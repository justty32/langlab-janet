# 資料 / IO 速查

spork/json・spork/argparse・檔案讀寫・marshal 序列化（Janet 1.41.2 實測）

## JSON · `spork/json`

```janet
(import spork/json)
(def d @{:name "Bob" :n 3})

(json/encode d)          ;=> {"name":"Bob","n":3}
(json/encode d "  " "\n") # 縮排好讀版

(json/decode s)          # key 是「字串」
(json/decode s true)     # ★ key 轉 keyword（建議）
```

**永遠傳 `true`**，解回來就能 `(d :name)` 用 keyword 取值，跟自己寫的 Janet 一致。

### 檔案 round-trip

```janet
(spit "c.json" (json/encode d "  " "\n"))
(def back (json/decode (slurp "c.json") true))
```

| JSON | Janet |
|---|---|
| object / array | `@{}` / `@[]` |
| string / number / bool | 同名 |
| null | keyword `:null`（decode 傳 3ⁿᵈ true → `nil`） |

### 巢狀取 / 改

```janet
(get-in j [:a :b 1])          # 取（別用 (j :a :b)）
(update-in j [:a :b 1] |(* $ 100)) # 改
(map |($ :n) users)          # decode 出來就是普通 array/table
```

> ⚠ **坑**：開 `nils=true` 時值為 `null` 的鍵會**整個消失**（table 存不了 nil）。

## CLI · `spork/argparse`

```janet
(import spork/argparse :as ap)
(def res
  (ap/argparse "說明"
    "name"  {:kind :accumulate :short "n"}
    "upper" {:kind :flag       :short "u"}
    "level" {:kind :option     :default "1"}
    :default {:kind :accumulate})) # 位置參數
(unless res (os/exit 1)) # nil = 失敗/印過help
```

給 `-n Alice --name Bob --upper p1 p2`：

```janet
(res "name")   ;=> @["Alice" "Bob"]
(res "upper")  ;=> true
(res "level")  ;=> "1"  (預設)
(res :default) ;=> @["p1" "p2"]
```

| :kind | 意思 | 型別 |
|---|---|---|
| `:flag` | 開關 | bool |
| `:multi` | 可多次、數次數 | int |
| `:option` | 帶一值 | string |
| `:accumulate` | 帶值可多次 | array |

`:option`/`:accumulate` 取回都是**字串**，要數字用 `:map scan-number`。`--help` 自動生成。

## ✦ 檔案 IO

```janet
(slurp "f.txt")          # 整檔讀進來 ★ 回的是 buffer 不是 string
(spit "f.txt" data)      # 整檔寫出（覆蓋）
(spit "f.txt" data :a)   # 附加
```

### 要串流才用 file/open

```janet
(with [f (file/open "f.txt" :r)]   # with 會自動 close
  (each line (file/lines f) …)      # 逐行，記憶體只吃一行
  (file/read f :all)                # :all / :line / n bytes
  (file/seek f :set 0)              # :set :cur :end
  (file/tell f))
(file/open p :w) # :r 讀 :w 覆寫 :a 附加 · 加 b=二進位 加 +=讀寫
(file/temp)       # 關掉就消失的暫存檔
```

### 路徑資訊 / 目錄

```janet
(os/stat p)          # table；不存在回 nil（不報錯）
(os/stat p :mode)    ;=> :file :directory :link :fifo …
(os/lstat p :mode)   # ★ 不跟隨 symlink（os/stat 會跟隨）
(os/dir d)           # 只回「名字」，不含路徑；不存在會 error
(os/mkdir d) (os/rm p) (os/rename a b) (os/rmdir d)
```

> ⚠ **原子寫入**：先 `spit` 到 `x.tmp` 再 `(os/rename "x.tmp" "x")`——同檔案系統上 rename 是原子的，中斷不會留半殘檔。

可跑：`snippets/file-io.janet`、`snippets/file-info.janet`、`snippets/list-dir.janet`。

## marshal 序列化

Janet 原生二進位序列化：**連閉包和暫停中的 fiber 都存得下**。

```janet
(marshal x)            ;=> buffer
(unmarshal bytes)      # 還原
(spit "c.jimage" (marshal data))  # 存檔
(unmarshal (slurp "c.jimage"))     # 讀回

# 存函式 / fiber 要給查找表，否則整個 core 會被塞進去
(marshal f (invert (env-lookup root-env)))
(unmarshal b (env-lookup root-env))
```

|  | JSON | marshal |
|---|---|---|
| 人看得懂 / 可 diff | ✓ | ✗ |
| 跨語言 | ✓ | ✗ |
| keyword / tuple / struct | ✗ | ✓ |
| 函式 / fiber | ✗ | ✓ |
| 換版本還讀得回 | ✓ | ✗ |

設定檔／進 git → JSON。快取／中繼檔／要保留型別 → marshal。**別拿 marshal 當長期儲存格式。**
