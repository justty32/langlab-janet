# spork/netrepl ・ 遠端 REPL

[← spork 索引](README.md)｜[← reference 索引](../README.md)

netrepl（network REPL）：把 Janet 的 REPL 開在網路上，讓別台機器（或同機的另一個終端機）連進來下指令、
共用一個執行環境——常見於「連進正在跑的 server 裡看現況、改個變數」。協定本身用 0xFF／0xFE 開頭位元組
區分「這是要即時求值的程式碼」跟「這是控制指令（如取消）」，正常互動還會開一條背景 fiber 持續把
`(dyn *out*)` 的輸出串流回client，比較複雜，這裡**只驗到「伺服器真的能起、能被連上」**，完整一問一答
protocol 沒有另外刻一份離線 client 去對——要用請直接接下面的 `client`。全部函式皆以 `janet -e` 實測於 1.41.2。

## API

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `server` | `(server &opt host port env cleanup welcome-msg)` | 起 REPL 伺服器，立刻回傳；`env` 給函式則**每條連線各自一個環境**，給 table 則**共用同一個** |
| `server-single` | `(server-single &opt host port env cleanup welcome-msg)` | 簡化版：固定共用單一環境（`env` 必須是 table，不能是函式） |
| `run-server` | `(run-server &opt host port env cleanup welcome-msg)` | 同 `server`，但卡住目前 fiber 直到伺服器關閉才回傳 |
| `run-server-single` | `(run-server-single &opt host port env cleanup welcome-msg)` | 同 `server-single`，一樣卡住等關閉 |
| `client` | `(client &opt host port name connect)` | 連上去，接管目前終端機當互動 REPL（跟內建 `janet` 的行為很像） |
| `default-host` | string | `"127.0.0.1"` |
| `default-port` | string | `"9365"` |

```janet
(import spork/netrepl)
(def srv-fiber (ev/spawn (netrepl/run-server-single "127.0.0.1" "42040" nil nil "歡迎\n")))
(ev/sleep 0.05)

(def stream (net/connect "127.0.0.1" "42040"))
(print "連線成功：" (if stream "yes" "no"))   # => 連線成功：yes
(:close stream)
(ev/cancel srv-fiber "test done")
```

實際互動請直接用內建的 `janet-netrepl`（jpm 裝 spork 時會一起裝）或程式裡 `(netrepl/client)`：

```
$ janet-netrepl -p 42040        # 另開一個終端機連上去，就是一個正常的 Janet REPL
```

⚠ `server`／`server-single` 都是「開好就走」，真正的連線處理在背景 fiber 跑；程式主體如果沒有其它事做，
記得呼叫 `run-server`／`run-server-single`（會卡住）或自己想辦法讓行程留著，否則主 fiber 結束整個行程就跟著關了。
