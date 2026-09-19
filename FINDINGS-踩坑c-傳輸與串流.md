# FINDINGS-踩坑 c — 傳輸與串流（接續 [踩坑 b](FINDINGS-踩坑b-工具鏈.md) 的編號）

[← FINDINGS.md](FINDINGS.md)｜[踩坑 a](FINDINGS-踩坑.md)｜[踩坑 b](FINDINGS-踩坑b-工具鏈.md)

補 https／Anthropic 原生／串流三個洞時實測踩到的。程式在 `modules/llm-http/`，
每條都在當場那一行有 ⚠。

## 十四、⚠ spork/http 的 `read-body` 對 `text/event-stream` 只讀**第一個事件**

本來想「先實測 `http/request` 能不能拿到整份 SSE body」，看原始碼就知道不行：

```janet
# spork/http.janet read-body
(when (-?>> (in headers "content-type") (string/has-prefix? "text/event-stream"))
  (read-until conn buf "\n\n")        # ← 讀到第一個空行就 break
  (put req :body buf) (break buf))
```

而且 `request` 把連線包在 `(defer (:close conn) …)` 裡，回來時 socket 已經關了，後面的事件全丟。
所以串流不能靠它。解法：借它的 `url-grammar`（解網址）與 `read-response`（解狀態列與 header），
body 自己讀——chunked 就逐塊解、有 content-length 就讀滿、都沒有就讀到 EOF（`stream-http.janet`）。
https 那條交給 `curl -N`（`stream-curl.janet`）。

一個小細節：`read-response` 回來的 `:buffer` **只剩 header 之後的殘餘 bytes**，chunked 的第一個
size 行常常已經在裡面，所以「先看 buf 再向 conn 要」的順序不能反。

## 十五、⚠ `(put table k v)` 回的是整張表，不是 `v`

寫串流的 tool_calls 合併時想「有 slot 就拿、沒有就建」：

```janet
(def slot (or (get calls idx) (put calls idx @{…})))   # ✘ slot 拿到的是 calls 本身
```

`put` 回傳的是 **table**（方便鏈式呼叫），於是 `(get-in slot [:function :name])` 是 nil，
`buffer/push` 炸出 `bad slot #0, expected buffer, got nil`。要先 `(def fresh @{…})`、`put` 進去、再用 `fresh`。
同理 `array/push` 回的也是 array。

## 十六、⚠ 金鑰不能上 curl 的命令列——`ps` 看得到

`-H "Authorization: Bearer sk-…"` 直接寫在 argv 裡，同機器任何人 `ps aux` 都看得到。
做法：header 寫進一個暫存檔，命令列只有 `-H @那個檔`；body 走 stdin（`--data-binary @-`）。
建檔用 `(os/umask 8r077)` 包住 `spit`，建出來就是 0600，沒有「先建再 chmod」的空窗；用完 `defer` 刪。
實測（假 curl 把 argv 記下來）：

```
argv: -sS -X POST -H @/tmp/llm-http-2a431d517d18de9f.hdr -w
%{http_code} --data-binary @- https://example.invalid/v1/chat/completions
```

另外兩個 curl 小坑：`--fail` 會把非 2xx 的 body **吞掉**（看不到伺服器的錯誤原文），改用
`-w '\n%{http_code}'` 把狀態碼接在最後一行自己切；讀 stdout／stderr 要在 `os/proc-wait` **之前**做完，
否則 pipe 塞滿子行程會卡住。

## 十七、Janet 沒有 `string/rfind`；`os/mkdtemp` 也沒有

要找「最後一個換行」得自己往回掃（`transport-curl.janet` 的 `last-newline`）。
暫存檔名用 `os/cryptorand` 產生，沒有 mkstemp 那套；有 `os/umask`／`os/chmod`（Janet 1.41.2 實測）。

## 十八、⚠ 假伺服器用 `http/router` 時，沒註冊的路徑先被它擋成 404

測「非 2xx 的錯誤訊息」時想讓假伺服器對 `/err` 回 429，結果拿到 `HTTP 404 … Not Found`：
`http/router` 只認註冊過的路徑，handler 裡的 `cond` 根本沒跑到。要測多條路徑就不要包 router，
handler 自己看 `(req :path)`。

## 十九、Anthropic 多輪 tool loop 要把 thinking block 原樣送回

Anthropic 回的 assistant `content` 可能含 `thinking`（帶 `signature`）block；下一輪送 tool_result 時
歷史裡的 assistant 訊息若少了它會被 400。但 Janet 這端的歷史是 OpenAI 形狀（`content`＋`tool_calls`），
重組不出 signature。解法：`from-anthropic` 轉回來的 message 多帶 `:anthropic_content`（原始陣列），
`to-anthropic` 看到它就**原樣**送回不重組。`test/llm-http-anthropic-loop.janet` 驗第二輪送出的
assistant 訊息第一個 block 仍是 `thinking`。⚠ 這份歷史若轉送到嚴格的 OpenAI 相容端點，要先拿掉這個 key。

（真打 api.anthropic.com 本機沒 key，未實測；以上是照 claude-api skill 的資料與假伺服器驗的。）
