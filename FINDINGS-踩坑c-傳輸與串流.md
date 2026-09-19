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

---

以下是 **2026-09-19 拿 DeepSeek（`deepseek-flash`）真打**時踩到的——前面十四～十九全是
假伺服器驗出來的，這一批才是第一次對真後端。

## 二十、⚠ 推理模型會把 `max_tokens` 全花在 `reasoning_tokens` 上

`(llm/ask ds "用一句話說明 Janet" nil nil :max-tokens 120)` 回空字串，HTTP 200：

```
finish → "length"
usage  → @{:completion_tokens 120 :completion_tokens_details @{:reasoning_tokens 120} …}
```

`ask` 本來就擋得住這件事（丟「答案被 max_tokens 截斷了（finish_reason=length）」的中文錯誤），
所以**不是 bug，是模型行為**。但 `ask-json` 更嚴重：送了 `response_format {:type "json_object"}`
之後，連「台北在哪個國家」這種問題也穩定燒掉 200 個 reasoning token，一次都成功不了。

解法是送 `:params {:reasoning_effort "none"}`（CLI：`--param reasoning_effort=none`），
同一題 200 tokens 就綽綽有餘。⚠ `"minimal"` **沒用**，實測照樣 200 全燒光，只有 `"none"` 有效。

## 二十一、⚠ CLI 的臨時 endpoint 沒辦法安全地給金鑰（已修）

`--url` ＋ `--model` 組出來的臨時 endpoint，金鑰只能走 `--api-key sk-…`——正好違反本模組
「金鑰不上命令列」那條原則（十六）。不給的話會靜靜落到 `defaults/proxy-key` 的 `dummy`：

```
呼叫 deepseek-live 失敗：HTTP 401（…）：{"error":{"message":"Authentication Fails,
Your api key: ****ummy is invalid","type":"authentication_error",…}}
```

`resolve.janet` 的 `build-cfg` 其實早就認得 overrides 的 `:api-key-env`，只是 CLI 沒有對應的旗標。
補上 `--api-key-env`（`cli-flags.janet`／`cli-args.janet`）就通了。
⚠ 兩個都給時 `--api-key` 贏，那是 `build-cfg` 的 `or` 順序，不是 CLI 的。

## 二十二、`models-url` 推出來的網址直接可用，不必加 `:models-url` 欄位

原本擔心 DeepSeek 的模型列表在 `/models` 而不是 `/v1/models`，`models-url` 會推錯。
實測**兩個都通**，回的是同一份：

```
https://api.deepseek.com/models    → @["deepseek-flash" "deepseek-v4-pro"]
https://api.deepseek.com/v1/models → @["deepseek-flash" "deepseek-v4-pro"]
```

所以沒有新增 `:models-url`。真撞到路徑對不上的後端，自己叫 `request-json` 就好，
不值得為此多一個欄位（`spec-keys` 每多一個，三個地方的錯誤訊息都要跟著改）。

## 二十三、⚠ `:transport :http` 蓋不掉「https → curl」

`use-curl?` 是 `(or (= :curl (cfg :transport)) (string/has-prefix? "https://" u))`——
`:transport :http` 只是「沒有明講要 curl」，https 仍然贏。這是**刻意的**（spork/http 沒有 TLS，
讓它去打 https 只會失敗），但寫設定的人容易以為 `:transport` 是最終決定權。

要驗「net 手寫那條對 https 的反應」只能直接叫 `stream-http/stream-post`，
它會**立刻**丟 `stream-http 只走 http://，https 請走 curl`，不會卡住（實測確認）。

## 二十四、⚠ trace 截斷切在 byte 上，會把中文剖一半（已修）

agent 的 trace 印工具結果時截到 200 —— 但 Janet 的 `length`／`string/slice` 都是以 **byte** 計的，
一個中文字 3 bytes，於是終端上真的看到 `…都裝在 ~/.local（原始碼編譯、不�…`。
修法是往回退到 UTF-8 的字元邊界（接續 byte 是 `0b10xxxxxx`），見 `trace.janet` 的 `utf8-cut`。
同一個坑的另一面在 `trace.janet` 檔頭已經寫過了：**印中文不要用 `%q`**，它會逃逸成 `\xE5\x8F\xB0`。
⚠ `protect` 回來的錯誤訊息用 `printf "%q"` 印也會中招，要 `(string e)` 再 `%s`。
