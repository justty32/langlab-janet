# 壓縮與封存 ・ spork/zip

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/zip` 是**原生模組**（已確認能 `import`），讀寫 `.zip` 封存檔（跟 `unzip`／檔案總管能開的那種），
也內建 deflate 壓縮／解壓縮（不包 zip 格式，單純壓位元組）。心智模型：**writer 負責寫、reader 負責讀**，
兩邊都可以對「記憶體 buffer」或「磁碟檔案」操作。

## 函式一覽

| 函式 | 簽名 | 說明 |
|---|---|---|
| `zip/write-buffer` | `(zip/write-buffer)` | 開一個寫進記憶體的 writer |
| `zip/write-file` | `(zip/write-file dest-path)` | 開一個直接寫進磁碟檔案的 writer |
| `zip/add-bytes` | `(zip/add-bytes writer path data &opt comment flags)` | 把一段位元組加進 zip，`path` 是壓縮包內的路徑 |
| `zip/add-file` | `(zip/add-file writer path filename &opt comment flags)` | 把磁碟上 `filename` 這個檔讀進來加到 zip 的 `path` |
| `zip/writer-finalize` | `(zip/writer-finalizer writer)` | 結束寫入，回傳完整的 zip 位元組（buffer，用於 `write-buffer`） |
| `zip/writer-close` | `(zip/writer-close writer)` | 結束寫入並關閉底層資源（用於 `write-file`） |
| `zip/read-bytes` | `(zip/read-bytes bytes &opt flags)` | 從記憶體 buffer 開一個 reader |
| `zip/read-file` | `(zip/read-file filename &opt flags)` | 從磁碟上的 `.zip` 檔開一個 reader |
| `zip/reader-count` | `(zip/reader-count reader)` | 這個 zip 裡有幾個項目 |
| `zip/get-filename` | `(zip/get-filename reader idx)` | 第 `idx` 項的檔名 |
| `zip/locate-file` | `(zip/locate-file reader path &opt comment flags)` | 用路徑反查索引，找不到回 `nil` |
| `zip/stat` | `(zip/stat reader idx)` | 該項目的完整 metadata（大小、CRC、時間…） |
| `zip/file-directory?` | `(zip/file-directory? reader idx)` | 這項是不是目錄（路徑以 `/` 結尾那種） |
| `zip/file-encrypted?` | `(zip/file-encrypted? reader idx)` | 這項有沒有加密 |
| `zip/file-supported?` | `(zip/file-supported? reader idx)` | 這項用的壓縮方式是否支援解壓（有些冷門演算法不支援） |
| `zip/extract` | `(zip/extract reader idx-or-filename &opt into flags)` | 解出一項的內容；`into` 給 buffer 就接到後面，不給就回傳新 buffer |
| `zip/reader-close` | `(zip/reader-close reader)` | 關閉 reader |
| `zip/compress` | `(zip/compress bytes &opt level into)` | 單純 deflate 壓縮（不是 zip 檔格式，只是壓位元組） |
| `zip/decompress` | `(zip/decompress bytes &opt into)` | 對應的解壓縮 |
| `zip/version` | `(zip/version)` | 底層 miniz 函式庫版本字串 |

## 實測：記憶體讀寫全流程

```janet
(import spork/zip)
(def w (zip/write-buffer))
(zip/add-bytes w "hello.txt" "Hello, World!")
(zip/add-bytes w "dir/nested.txt" "nested content" "a comment")
(def buf (zip/writer-finalize w))
(length buf)                              # => 288

(def r (zip/read-bytes buf))
(zip/reader-count r)                      # => 2
(zip/get-filename r 0)                    # => "hello.txt"
(zip/get-filename r 1)                    # => "dir/nested.txt"
(zip/file-directory? r 0)                 # => false
(zip/file-encrypted? r 0)                 # => false
(zip/file-supported? r 0)                 # => true
(zip/stat r 0)
# => {:bit-flag 2056 :comment "" :comp-size 13 :crc32 -330644528
#     :external-attr 0 :filename "hello.txt" :index 0 :internal-attr 0
#     :method 0 :time 1788018070 :uncomp-size 13 :version-made-by 0 :version-needed 0}
(zip/locate-file r "hello.txt")           # => 0

(def out (buffer/new 0))
(zip/extract r 0 out)
(print out)                               # => Hello, World!
(zip/extract r "dir/nested.txt" out)
(print out)                               # => Hello, World!nested content   ← ⚠ 見下方
(zip/reader-close r)
```

⚠ **`zip/extract` 是「附加」到 `into`，不會先清空**：上面第二次 `extract` 沒有覆蓋 `out`，
而是接在前一次的內容後面。要重複用同一個 buffer，記得每次先 `buffer/clear`。

## 實測：目錄項目、`add-file`（從磁碟讀）

```janet
(import spork/zip)
(def w (zip/write-buffer))
(zip/add-file w "copied.txt" "/path/to/src.txt")   # 把磁碟檔讀進來存成 zip 內的 copied.txt
(zip/add-bytes w "adir/" "")                        # 路徑以 / 結尾 → 視為目錄項目
(def r (zip/read-bytes (zip/writer-finalize w)))
(zip/reader-count r)          # => 2
(zip/file-directory? r 1)     # => true
(zip/get-filename r 1)        # => "adir/"
```

## 實測：直接寫讀磁碟檔案

```janet
(import spork/zip)
(def w (zip/write-file "/tmp/test.zip"))
(zip/add-bytes w "a.txt" "content A")
(zip/writer-close w)

(def r (zip/read-file "/tmp/test.zip"))
(zip/reader-count r)   # => 1
(zip/reader-close r)
```
確實在磁碟上產生了一個 133 bytes 的 `test.zip`，且能重新讀回。

## 實測：純壓縮（不經 zip 格式）

```janet
(import spork/zip)
(def c (zip/compress "hello hello hello hello hello"))
(length c)                 # => 17   （30 bytes 壓成 17）
(zip/decompress c)         # => "hello hello hello hello hello"
(zip/version)              # => "11.0.1"
```
