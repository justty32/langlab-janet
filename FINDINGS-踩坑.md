# 實作時踩到的坑

[← 環境與架構筆記](FINDINGS.md)

架構怎麼決定的在 [FINDINGS.md](FINDINGS.md)；這一份是**動手寫的時候**
被環境或 API 咬到的地方，編號延續前一份。

## 七、⚠ HTTP header 的值只能是 ASCII

`llm-http` 的 endpoint 可以帶自訂 `:headers`，但**值放中文會被伺服器擋成 400**
（實測 spork/http 的 server 就是這樣回）。HTTP header 本來就只吃 ASCII／ISO-8859-1，
要帶非 ASCII 的東西請放進 body。

症狀很不直覺：payload 一切正常、URL 也對，就是回一個沒有 body 的 `HTTP 400`。
先檢查有沒有在 header 裡塞中文。

## 八、使用者設定檔：只 parse 不 eval

兩個模組（`llm-http` 的 endpoint、`pi-shell` 的 agent）都讓使用者用一份設定檔
擴充內建清單，設計上共用同一套決定：

- **只 `parse-all` 不 `eval`**。檔案是**資料字面值**不是程式，所以裡面寫
  `(os/shell "…")` 也只是一個沒人執行的 tuple。代價是設定檔裡不能算東西
  （例如讀環境變數），所以另外開了 `:api-key-env` 這種欄位讓它宣告式地表達。
  `parse-all` 在 Janet 1.41.2 是內建的，回一個 array，多個 top-level 值會依序排好。
- **「沒有設定檔」是正常狀態**，自動探測找不到就靜靜跳過，不輸出也不報錯；
  找到了但壞掉只在 stderr 印一行中文警告然後當作沒載入——一份壞掉的設定檔
  不該讓「只想用內建那筆」的人整個跑不起來。明確呼叫 `load-endpoints!`／`load-agents!`
  時才會丟例外（那是使用者主動要求的，靜默失敗反而糟）。
- ⚠ **自動載入是 `import` 的副作用**，所以**測試一開頭要先 `reset-endpoints!`／`reset-agents!`**，
  否則開發機上有一份 `~/.config/llm-http/endpoints.janet` 就會讓測試結果跟別人不一樣。
  想要「純函式、零 IO」的那一層請直接 import `registry.janet`／`agents.janet`，
  它們不碰檔案系統。

## 九、驗證現況（2026-08-04 這次改動）

改完 registry／設定檔／參數合併之後**沒有**做真模型端到端驗證：這台機器上
**LM Studio（`127.0.0.1:1234`）與 litellm proxy（`127.0.0.1:4000`）當時都沒在跑**
（`ss -lnt` 兩個 port 都沒有 listener），而 `local` 這條線的後端就是 LM Studio，
所以就算把 proxy 起起來也打不到模型。

改用**同一個行程裡的假 OpenAI 相容後端**（spork/http 的 server）把整條路徑走完：
CLI → registry → 參數合併 → `post-chat` → HTTP → 解回應 → tool loop。
**傳輸與組裝這一段是驗過的；「真模型會不會照那些參數辦事」沒驗過。**

## 十、⚠ 推理模型會把 `max_tokens` 花在 reasoning 上，content 回空字串

2026-08-04 在 LM Studio ＋ `google/gemma-4-e4b` 上實測到的。`max_tokens` 開太小時：

```
finish_reason = "length"
content       = ""                    ← 空字串，不是 nil
usage         = {completion_tokens: 8, completion_tokens_details: {reasoning_tokens: 5}}
```

**HTTP 仍然是 200**，所以光看狀態碼完全看不出問題。給到 120 個 token 也一樣——
其中 117 個是 reasoning，content 還是空的。這顆模型的推理預算就是這麼吃。

踩點在於：`""` 是合法字串，一路過關到呼叫端，看起來像「模型沒話說」。
處理方式：`chat.janet` 加了 `reply-finish-reason`／`truncated?`，`ask` 遇到
「截斷且 content 為空」時直接丟中文錯誤並附上 usage；CLI 則在 stderr 警告
（包含只截斷、content 非空的情況——那時答案是**半截的**，更該講）。

> 教訓推廣：**看 `finish_reason`**。被截斷、觸發內容過濾、模型要叫工具，
> 全都是 HTTP 200，只有這個欄位講得出來。

## 十一、⚠ `jpm build` 不會因為你改了「非入口」的檔案就重編

實測：改了 `modules/llm-http/chat.janet` 與 `cli.janet` 之後跑 `jpm build`，
它**什麼都沒做**，`build/llm-http` 的時間戳原封不動，跑起來還是舊行為——
很容易誤判成「我的修改沒生效」而去亂改程式。

原因是 jpm 的 executable 規則只把 `:entry` 那一支當相依，**不追它 import 進來的檔案**。
`main.janet` 沒動，規則就認為是最新的。

改非入口檔之後要嘛 `jpm clean && jpm build`，要嘛 `touch` 一下 entry。
