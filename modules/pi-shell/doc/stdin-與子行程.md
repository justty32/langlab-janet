# stdin 與子行程

[← 回 pi-shell README](../README.md)


**這是時序問題，不是管線壞掉。**

`pi` 在**啟動當下**檢查 stdin 有沒有東西可讀。shell 的 `echo x | pi` 在 pi 開始跑之前，
資料就已經躺在管線 buffer 裡了；但 `os/spawn` ＋ `:in :pipe` 是**先 spawn、後寫入**，
pi 檢查的那一瞬間管線還是空的，於是它判定「沒有管線輸入」——實測會回你
「無法讀取 stdin，沒有輸入」。

（`claude -p` 跟一般 node 程式是**事件式**等到 EOF 才收工，對這個時序不敏感，
所以它們用管線也收得到——很容易讓人誤判成「管線沒問題、是 pi 壞了」。）

修法是把 stdin 換成**內容已經就緒的檔案句柄**，子行程一開工就讀得到：

```janet
(def f (file/temp))                 # 匿名暫存檔，close 掉就消失，不用善後
(file/write f stdin-str)
(file/flush f)
(file/seek f :set 0)                # ★ 一定要倒帶！
(os/spawn cmd :p {:in f :out :pipe})
```

⚠ **`(file/seek f :set 0)` 沒做的話，子行程會從檔尾開始讀 = 靜默讀到空**，
不會有任何錯誤訊息，非常難查。

這條路對 `pi` 與 `claude` **都有效**，所以 `proc.janet` 統一走它，不為兩支 agent 分岔；
stdin 那半也因此不再需要背景 fiber。**但讀 stdout 仍然維持「邊跑邊讀」**（見下一節）。

## 子行程的幾個重點

管線寫法照 [`../../snippets/pipe-to-child/main.janet`](../../../snippets/pipe-to-child/main.janet)：

- `(os/spawn cmd :p {:out :pipe})` 才會拿到 stdout 管線；`:p` = 走 PATH 找執行檔。
- ★ **stdout 一定要邊跑邊讀**（背景 fiber `drain`），別改成「先 `os/proc-wait` 再讀」——
  輸出量一大就塞爆 pipe buffer 死鎖。
- stdin 走暫存檔句柄（見上一節）；沒東西要餵時才給管線並立刻 `(:close (proc :in))` 送 EOF。
- ★ 收工一定要 `(os/proc-wait proc)`，否則留下殭屍行程。
- stderr 不接管線、直接繼承，所以子行程的進度訊息照常出現在終端。

刻意**不**加 `:x`——非 0 退出碼是**資料**（回在 `:code` 裡），不是例外。
