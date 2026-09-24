# 11-4 · todo：測試與打包

todo 已經能用了，但每改一次就手動打一輪 add、list、done 很累，也很容易漏。這課幫它補上自動測試，然後用 `jpm build` 把它編成一支不用裝 Janet 也能跑的執行檔。學完你會知道測試檔怎麼擺、怎麼不弄髒真的資料，以及打包時最容易中的一個坑。

## 這是什麼、為什麼

9-3 講過：在 Janet 裡，一支測試就是一支普通的 `.janet` 程式，從頭跑到尾沒出事就是通過，中途丟錯就是失敗。這課不再教新語法，而是把那套規矩用在一個真的專案上。

真專案多出來的問題有兩個。第一，todo 會讀寫檔案，測試不能去動你真的在用的 `todo.json`。第二，打包成執行檔之後，程式的行為可能跟 `janet main.janet` 跑的時候不一樣，要知道差在哪。

## 動手：測試放哪、怎麼跑

專案的測試都在 `examples/course/11-todo/test/`：

```
test/helper.janet    測試共用的小工具（只有定義）
test/store.janet     資料層的測試
test/cli.janet       指令層的測試
```

`jpm test` 會把 `test/` 底下每一支 `.janet` 各開一個行程（process，作業系統裡一個獨立在跑的程式）跑一遍，任何一支用非 0 的 exit code 結束，整個測試就算失敗。

所以 `helper.janet` 也會被單獨跑一次。它只放 `defn`，不印東西、不做事，被單獨跑也就是「定義完三個函式然後結束」，不會出事。你在輸出裡會看到 `running test/helper.janet ...` 後面什麼都沒有，就是這個原因。

## 動手：暫存目錄與 defer

測試要讀寫檔案，就得有個「用完就丟」的地方。`helper/temp-dir` 在 `$TMPDIR` 底下開一個新目錄，沒設 `TMPDIR` 就用 `/tmp`：

```janet
(defn temp-dir
  [tag]
  (def base (os/getenv "TMPDIR" "/tmp"))
  (def dir (string base "/todo-test-" tag "-" (os/time) "-" (math/floor (* 1000 (math/random)))))
  (os/mkdir dir)
  dir)
```

目錄名稱裡塞了時間和亂數，兩支測試同時跑也不會撞在一起。`os/getenv` 的第二個參數是「找不到時的預設值」，印出來看看：

```janet
(print (os/getenv "TMPDIR" "/tmp"))
# 印出：/tmp（你的機器有設 TMPDIR 就是那個值）
```

開了目錄要記得刪。測試檔的開頭長這樣：

```janet
(def dir (helper/temp-dir "store"))
(defer (helper/cleanup dir)
  (def path (string dir "/todo.json"))
  # ……所有測試都寫在這裡面……
  )
```

`defer` 是 7-2 教過的：不管裡面是正常跑完，還是某個 `assert` 失敗丟錯，`(helper/cleanup dir)` 都一定會跑。測試失敗時錯誤照樣往外丟（jpm 才知道失敗了），只是丟之前先把暫存目錄清掉。範例檔 `examples/course/11-4.janet` 的「defer」段落故意在中間丟錯，跑完目錄確實不見了。

## 動手：test/store.janet 在驗什麼

這支只測資料層，不碰命令列、不看輸出。逐段看：

檔案不存在時，`load` 要回一份空資料，而且不能順手建檔。第二條很容易漏：只是 `list` 一下就生出一個空檔，使用者會很困惑。

```janet
(def db (store/load path))
(assert (deep= db @{:next-id 1 :items @[]}) "不存在的檔應該給一份空資料")
(assert (nil? (os/stat path)) "load 不該自己建檔")
```

這裡用 `deep=`（比內容的相等，3-3 講過），因為兩個 table 用 `=` 比的是「是不是同一個」，一定不相等。

接著 add 兩筆，確認 id 是 1、2，`next-id` 走到 3。然後存檔再讀回來，要跟原本一模一樣，中文也要活著回來：

```janet
(store/save path db)
(def back (store/load path))
(assert (deep= back db) "round-trip 之後資料要一樣")
(assert (= "買牛奶" (get-in back [:items 0 :text])) "中文要能讀回來")
```

round-trip 就是「寫出去再讀回來」。存檔時中文會被逃逸成 `\uXXXX`（打開 todo.json 就看得到），這條就是在確認讀回來會還原。

`done` 和 `rm` 各測兩種 id：存在的要回那一筆，不存在的要回 `nil`。`rm` 還多測一次「同一個 id 刪兩次」，第二次要回 `nil`。

壞檔的訊息要帶路徑，使用者才知道去修哪個檔。`helper/err-of` 跑一個函式、斷言它一定失敗，再把錯誤訊息交回來給你檢查：

```janet
(spit path "{oops")
(def msg1 (helper/err-of |(store/load path)))
(assert (string/find path msg1) "語法錯的訊息要帶路徑")
```

`err-of` 裡面其實就是 `protect` 加 `assert`。自己試一下 `protect` 接住 `assert` 的樣子：

```janet
(def [ok e] (protect (assert false "boom")))
(not ok)      # => true
(string e)    # => "boom"
```

最後是 `data-path` 的三層優先順序：參數 > 環境變數 `TODO_FILE` > `todo.json`。環境變數用 `os/setenv` 臨時改，測完一定要用 `nil` 改回去，不然會影響同一支檔後面的測試：

```janet
(os/setenv "TODO_FILE" "/env/z.json")
(assert (= "/env/z.json" (store/data-path)) "沒給參數就看環境變數")
(os/setenv "TODO_FILE" nil)
```

指令層的測試與 `jpm test` 的輸出，接著看 [11-4b · 指令層測試與 jpm test](11-4b-todo-指令層測試.md)。
