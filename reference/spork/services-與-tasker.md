# services／tasker ・ 背景服務與工作佇列

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/services` 管一群**長駐**的背景工作（server、監控迴圈……），每個服務有自己的 log 檔、可以單獨
重啟／停掉；概念上是 supervisor（監督者：專門盯著一群 worker，掛了就處理）。`spork/tasker` 管一批
**做完就結束**的一次性任務（用子行程跑，寫進磁碟排隊、可設優先序與逾時）。兩者都是「結構化並行」
（`ev-utils` 的 nursery）加上磁碟落地跟log的實務封裝。全部函式皆以 `janet -e` 實測於 1.41.2。

## services

| 名字 | 型別 | 一句話 |
|---|---|---|
| `make-manager` | function `(make-manager &opt log-dir)` | 建一個服務管理器，log 檔預設寫在 `log-dir`（預設目前目錄） |
| `get-manager` | function `(get-manager)` | 拿目前 `(dyn *current-manager*)`，沒有就自動建一個 |
| `add-service` | function `(add-service service-name main-function & args)` | 用 `main-function` 起一個服務（跑在自己的 fiber），回傳服務名 |
| `stop-service` | function `(stop-service service-name &opt reason)` | 取消該服務的 fiber，關掉它的 log 檔 |
| `start-service` | function `(start-service service-name)` | 停掉再重啟同一個服務 |
| `remove-service` | function `(remove-service service-name)` | 停掉並從管理器移除（`all-services` 之後就查不到它了） |
| `get-service` | function `(get-service)` | 在服務自己的 fiber 內部呼叫，拿到代表自己的那個服務物件 |
| `set-title` | function `(set-title title)` | 服務自己更新一行「目前在幹嘛」的說明文字（給 `print-all` 看） |
| `wait` | function `(wait)` | 卡住呼叫者直到管理器被取消，取消時順便停掉所有服務——讓管理者本身也能被當服務對待 |
| `all-services` | function `(all-services &opt manager)` | 列出目前管理器裡的服務名 |
| `print-all` | function `(print-all &opt manager filter-fn)` | 印一張服務狀態表（名字／說明／狀態／最後錯誤／啟動時間） |
| `run-subprocess` | function `(run-subprocess prog & args)` | 現成的服務主體：起一個子行程、等它結束 |
| `run-module-in-thread` | function `(run-module-in-thread module-name &opt func & args)` | 現成的服務主體：在一條新的系統執行緒上跑某模組的函式 |
| `*current-service*` | keyword | dynamic binding 的 key，服務內部可 `(dyn *current-service*)` |
| `*current-manager*` | keyword | dynamic binding 的 key，管理器內部可 `(dyn *current-manager*)` |

```janet
(import spork/services)
(def manager (services/make-manager "./svc-logs"))
(setdyn services/*current-manager* manager)

(services/add-service :ticker
  (fn [] (services/set-title "跑圈圈中") (forever (ev/sleep 0.02))))
(ev/sleep 0.05)
(services/print-all)
# => ╭──────┬────────┬──────┬──────────┬───────────────────╮
#    │ Name │  Title │Status│Last Error│     Started At    │
#    │ticker│跑圈圈中│ alive│          │2026-08-29 15:46:30│
(pp (services/all-services))     # => @[:ticker]

(services/remove-service :ticker)
(pp (services/all-services))     # => @[]
```

⚠ **`run-subprocess` 有 bug**：原始碼判斷結果那段誤用了 `when` 而不是 `if`
（`(when (zero? rc) (print "成功") (do (printf "失敗: %d" rc) (error ...)))`），
`when` 的 body 是「條件成立就依序全跑」，不是二選一分支。實測結果：子行程**成功**（`rc=0`）時，
`when` 條件成立 → 兩段全部執行 → 先印「finished successfully」又印「finished with non-zero exit code: 0」
還真的 `error` 出去；子行程**失敗**（`rc≠0`）時條件不成立、整段被跳過，反而**什麼都不做，不報錯也不印**。
也就是說目前這個函式的成功/失敗判斷完全反了。真的要用 `run-subprocess` 當服務主體，自己包一層處理結果比較保險。

## tasker

一次性任務走「排進佇列 → executor 從佇列拿 → 開子行程跑 → 結果連中繼資料一起寫回磁碟」這條路，
中斷後重開行程還能從磁碟撿回未完成的任務（`new-tasker` 內部會做）。

| 名字 | 型別 | 一句話 |
|---|---|---|
| `new-tasker` | function `(new-tasker &opt task-directory queues queue-size)` | 建一個 tasker，`task-directory` 存任務記錄，`queues` 是佇列名清單（預設 `[:default]`） |
| `queue-task` | function `(queue-task tasker argv &opt note priority qname timeout expiration input)` | 排一個任務，`argv` 是子行程指令陣列，回傳 task-id |
| `spawn-executors` | function `(spawn-executors tasker &opt qnames workers-per-queue pre-task post-task)` | 啟動幾條 executor fiber 開始從佇列拿任務執行，立刻回傳 |
| `run-executors` | function `(run-executors tasker &opt workers-per-queue pre-task post-task)` | 同上，但卡住等所有 executor 結束（配 `close-queues` 用） |
| `close-queues` | function `(close-queues tasker)` | 佇列關閉，不再收新任務；executor 做完手上這件就會自然結束 |
| `cancel-task` | function `(cancel-task tasker task-id)` | 殺掉正在跑的子行程／標記排隊中的任務為取消 |
| `task-status` | function `(task-status tasker task-id)` | 讀該任務目前的完整中繼資料（табle） |
| `all-tasks` | function `(all-tasks tasker &opt detailed)` | 列出磁碟上還有記錄的任務 id（或給 `detailed` 拿完整資料） |
| `task-file` | function `(task-file tasker task-id &opt file-name)` | 該任務某個記錄檔的路徑（預設 `out.log`） |
| `run-cleanup` | function `(run-cleanup tasker)` | 刪掉磁碟上已過期（`delete-after` 已過）的任務記錄 |
| `statuses` | tuple | 全部可能狀態：`[:pending :running :done :canceled :timeout :error]` |
| `default-priority` / `min-priority` / `max-priority` | number | 預設 4，範圍 0～9，**數字越小越先執行** |
| `default-expiration` | number | 預設過期秒數（30 天） |
| `default-task-directory` | string | `"./tasks"` |
| `task-meta-name` / `out-file-name` / `err-file-name` | string | 每個任務目錄底下的檔名：`task.jdn`／`out.log`／`err.log` |

```janet
(import spork/tasker)
(def t (tasker/new-tasker "./tasks"))
(def id (tasker/queue-task t ["echo" "任務一"] "第一個任務"))
(pp (tasker/all-tasks t))          # => @[:task-xxxx]

(tasker/close-queues t)            # 先關佇列，run-executors 才會在做完後自然結束
(tasker/run-executors t)
# => starting executor 0 for queue default / starting task task-xxxx / finished task task-xxxx normally

(pp (get (tasker/task-status t id) :status))   # => :done
(print (slurp (tasker/task-file t id)))        # => 任務一   （子行程的 stdout）
```

⚠ 順序：`spawn-executors`／`run-executors` 要在 `queue-task` 之後呼叫才吃得到任務；如果先
`close-queues` 才 `queue-task`，該次 `queue-task` 會直接卡死（`ev/give` 一個已關閉的 channel）。
`run-executors` 內部本身就會呼叫一次 `spawn-executors`，兩個**不要疊著呼叫**，否則會起兩批 executor。
