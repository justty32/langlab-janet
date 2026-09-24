# 11-3b · todo 指令層（續）

接續 [11-3 · todo 指令層](11-3-todo-指令層.md)。上一篇有了 `parse`、`with-db`、`cmd-add`，這篇補完 `list`、`done`、`rm`，再寫總入口 `run`。

## 動手（續）

### cmd-list：多一個 --all

```janet
(defn cmd-list [args]
  (def res (parse "list" "列出全部" args
                  "all" {:kind :flag :short "a" :help "連做完的也列出來"}))
  (unless res (break 1))
  (with-db res
    (fn [db]
      (def items (if (res "all")
                   (db :items)
                   (filter |(not ($ :done)) (db :items))))
      (if (empty? items)
        (print "（沒有事情）")
        (each it items
          (printf "[%s] %d  %s" (if (it :done) "x" " ") (it :id) (it :text))))
      0)))
```

`--all` 是 flag（有打就是 true，沒打就是 nil），所以直接拿來當 `if` 的條件。沒打的時候用 `filter` 只留還沒做完的。拿幾筆假資料試：

```janet
(def items @[{:id 1 :done false} {:id 2 :done true}])
(def left (filter |(not ($ :done)) items))
(length left)  # => 1
(printf "[%s] %d  %s" " " 1 "milk")
# 印出：[ ] 1  milk
```

`printf` 的格式字串跟 `string/format` 一樣。`%s` 放字串，`%d` 放整數，做完的打 `x`、沒做完的放一個空白，方括號就會對齊。

`list` 其實只讀不改，但為了少寫一套讀檔程式，它也走 `with-db`，副作用是會把檔案原樣存回去一次。

### parse-id：id 要是正整數

`done 2`、`rm 3` 的參數是字串 `"2"`、`"3"`，要轉成數字。`scan-number` 把字串讀成數字，讀不懂就回 nil：

```janet
(scan-number "abc")  # => nil
(scan-number "2")    # => 2
(scan-number "2.5")  # => 2.5
(scan-number "-3")   # => -3
```

光是「讀得懂」還不夠，`2.5`、`-3` 都不是合法的 id。所以再檢查 `int?`（是整數）和 `pos?`（大於 0）：

```janet
(defn parse-id [res]
  (def s (get-in res [:default 0]))
  (def n (and s (scan-number s)))
  (when (and n (int? n) (pos? n)) n))
(parse-id @{:default @["2"]})    # => 2
(parse-id @{:default @["2.5"]})  # => nil
(parse-id @{:default @["abc"]})  # => nil
(parse-id @{})                   # => nil
```

`get-in` 拿位置參數的第一格，沒給就是 nil。`(and s ...)` 讓 nil 一路傳下去，不會拿 nil 去呼叫 `scan-number` 而炸掉。專案裡它是 `defn-`，這裡為了能單獨跑寫成 `defn`。

### cmd-by-id：done 與 rm 長一樣

`done` 和 `rm` 幾乎是同一段程式：拿 id、叫資料層、印「完成 #2」或「刪除 #3」。不同的只有「叫哪個資料層函式」和「印哪個動詞」，所以把這兩樣當參數傳進來：

```janet
(defn- cmd-by-id [name desc args action verb]
  (def res (parse name desc args :default {:kind :accumulate :help "<id>"}))
  (unless res (break 1))
  (def id (parse-id res))
  (unless id
    (eprintf "%s：要給一個正整數 id，例：todo %s 2" name name)
    (break 1))
  (with-db res
    (fn [db]
      (if-let [item (action db id)]
        (do (printf "%s #%d：%s" verb (item :id) (item :text)) 0)
        (do (eprintf "找不到 #%d" id) 1)))))

(defn cmd-done [args] (cmd-by-id "done" "標成完成" args store/done "完成"))
(defn cmd-rm   [args] (cmd-by-id "rm"   "刪掉一件事" args store/rm   "刪除"))
```

`action` 收到的是 `store/done` 或 `store/rm` 這個函式本身。11-2 把它們寫成「找到回那一筆，找不到回 nil」，這裡就用得上：`if-let` 先算 `(action db id)`，拿到東西就綁給 `item` 走第一支，拿到 nil 走第二支。

### commands、usage、run：總入口

```janet
(def commands
  {"add" cmd-add "list" cmd-list "done" cmd-done "rm" cmd-rm})

(defn usage []
  (eprint "用法：todo <add|list|done|rm> [參數] [--file 路徑]")
  (eprint "每個子命令都有 --help，例：todo add --help"))

(defn run [args]
  (def sub (get args 0))
  (def handler (get commands sub))
  (cond
    (nil? sub) (do (usage) 1)
    (nil? handler) (do (eprintf "未知子命令 %q" sub) (usage) 1)
    (let [[ok v] (protect (handler (array/slice args 1)))]
      (if ok v (do (eprint "錯誤：" v) 1)))))
```

`commands` 是一張查表：子命令名字對到函式。這就是分派（dispatch，照名字決定叫誰）。要加子命令，寫一個函式、在表裡多放一格就好，`run` 不用改。

`cond` 有三種情況。沒給子命令，印用法回 1。給了但表裡查不到，印出打錯的字再印用法（`%q` 會把字串帶引號印出，看得出是 `"foo"`）。最後一條沒有條件，是「其他情況」：把子命令後面的字切下來交給 handler。

`protect` 是 7-1 學的：跑一段程式，回傳 `[成功嗎 值或錯誤]`。資料層遇到壞檔會 `errorf`（11-2），不接的話使用者會看到一整片 stack trace。這裡接住，印成一行「錯誤：…」回 1：

```janet
(defn handler [] (error "bad json"))
(def [ok v] (protect (handler)))
(tuple ok v)  # => (false "bad json")
```

### 為什麼錯誤走 eprint

結果用 `print` 印到 stdout（標準輸出），錯誤和用法用 `eprint` 印到 stderr（錯誤輸出）。終端機上兩條都顯示，看不出差別。差別在接管線或存檔的時候：

```sh
$ todo list > 清單.txt    # 清單.txt 只有待辦，沒有錯誤訊息混進去
$ todo done 9 > /dev/null
找不到 #9                 # stdout 丟掉了，錯誤還是看得到
```

別的程式讀你的輸出時，只會讀到乾淨的結果；出事時人照樣看得到訊息，exit code 也告訴腳本「失敗了」。

實際跑一遍與會踩的坑在續篇：[11-3c · todo 指令層跑起來](11-3c-todo-指令層.md)
