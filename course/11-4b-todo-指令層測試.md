# 11-4b · todo：指令層測試與 jpm test

接 [11-4](11-4-todo-測試與打包.md)。資料層測完了，這篇測指令層：打一個指令進去，看 exit code 對不對、印出來的字對不對。最後實際跑一次 `jpm test`。

## 動手：不開子行程，直接叫 cli/run

最直覺的做法是真的在 shell 裡跑 `janet main.janet add 買牛奶`，再去讀它印出來的東西。這要開子行程（從程式裡再啟動另一支程式），慢，又要處理一堆輸出接線。

todo 的設計讓我們可以繞過這件事：`main.janet` 只是把參數交給 `cli/run`，`cli/run` 回傳 exit code，不自己 `os/exit`。所以測試直接呼叫 `cli/run`，就等於跑了一次指令，而且拿得到回傳值。

剩下的問題是：`cli/run` 會把結果 print 到螢幕上，測試要怎麼拿到那些字？這要靠 spork 的兩個工具。

## 動手：capture-stdout 與 suppress-stderr

`test/capture-stdout` 把一段程式碼印出來的東西攔下來，回傳一個兩格的 tuple（一串放進去就不能改的值）：第一格是那段程式碼的回傳值，第二格是印出來的字。

```janet
(import spork/test)
(def r (test/capture-stdout (do (print "hi") 42)))
(first r)   # => 42
(last r)    # => "hi\n"
```

⚠ 順序是 `[回傳值 印出來的字]`，不是反過來。寫反了不會馬上報錯，只會讓你的比對永遠不成立，然後你盯著一個明明對的輸出懷疑人生。

`test/suppress-stderr` 把錯誤輸出（stderr）吞掉，回傳值照樣交出來。todo 的錯誤訊息都走 `eprint`，測「故意打錯指令」時不吞掉，測試輸出會夾一堆「找不到 #99」，看起來像出事了：

```janet
(import spork/test)
(def code (test/suppress-stderr (eprint "這行不會出現") 1))
(print code)
# 印出：1
```

## 動手：test/cli.janet 在驗什麼

測試檔先包一個小幫手 `run`，每次都自動補上 `--file` 指到暫存檔，所以不管你電腦上有沒有設 `TODO_FILE`，測試都只碰暫存目錄：

```janet
(defn run
  [& args]
  (def [code out] (test/capture-stdout
                    (test/suppress-stderr (cli/run @[;args "--file" path]))))
  [code (string out)])
```

`suppress-stderr` 包在裡面、`capture-stdout` 包在外面，所以 stdout 被收下來、stderr 被丟掉，回傳值是 `cli/run` 的 exit code。`@[;args "--file" path]` 是把 `args` 攤開（`;` 是 splice，把一串東西拆開放進去），後面接上 `--file` 和路徑。

有了 `run`，每條測試都很短。它驗三種東西：

exit code。沒給子命令、未知子命令都要回 1：

```janet
(assert (= 1 (first (run))) "沒子命令 → 1")
(assert (= 1 (first (run "nope"))) "未知子命令 → 1")
```

印出來的字。`list` 預設藏掉做完的，`--all` 全列：

```janet
(assert (= "[ ] 2  倒垃圾\n" (last (run "list"))) "list 預設藏掉做完的")
(assert (= "[x] 1  買 牛奶\n[ ] 2  倒垃圾\n" (last (run "list" "--all"))) "--all 全列")
```

失敗的指令不動資料。打錯 id 之後，直接用 `store/load` 讀檔案，確認還是兩筆：

```janet
(assert (= 1 (first (run "done" "abc"))) "done abc → 1")
(assert (= 1 (first (run "rm" "99"))) "rm 99 → 1")
(assert (= 2 (length ((store/load path) :items))) "失敗的指令不動資料")
```

最後一段把資料檔寫壞，確認 `run "list"` 回 1，而不是整個炸出 stack trace。

這支檔同時用了內建的 `assert` 和 spork/test 的 `capture-stdout`。這樣混用完全沒問題：spork/test 的工具只是幫你拿到值，判斷對錯用哪一套都行。

## 動手：跑 jpm test

在 `examples/course/11-todo/` 裡跑：

```sh
$ jpm test
generating executable c source build/todo.c from main.janet...
found native /home/lorkhan/.local/lib/janet/spork/json.so...
compiling build/todo.c to build/build___todo.o...
linking build/todo...
running test/cli.janet ...
cli 測試通過 ✓
running test/helper.janet ...
running test/store.janet ...
store 測試通過 ✓
✓ All tests passed.
```

前四行是在編執行檔。`jpm test` 預設相依 `jpm build`，所以只要專案裡有 `declare-executable`，第一次跑測試會先 build。再跑一次，build 已經是最新的，前四行就不見了：

```sh
$ jpm test
running test/cli.janet ...
cli 測試通過 ✓
running test/helper.janet ...
running test/store.janet ...
store 測試通過 ✓
✓ All tests passed.
```

`build/` 這時已經在了。它是產物，不進 repo，跑完記得 `jpm clean`（下一篇會講）。

打包成執行檔、還有打包時的坑，接著看 [11-4c · 打包成執行檔](11-4c-todo-打包成執行檔.md)。
