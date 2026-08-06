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

## 十二、⚠ Windows：`jpm install` 裝不了原生模組會**靜默成功**，而且 manifest 會說謊

2026-08-06 實測。症狀是最難查的那一種：

```
jpm install spork      # exit 0，一行輸出都沒有，什麼也沒裝
```

而 `janet -e '(import spork/utf8)'` 回 `could not find module`。八顆原生模組
（`utf8 base64 crc zip cmath rawterm tarray gfx2d`）**一顆都沒進去**，只有
`json.dll` 在——那是更早以前裝的。

**為什麼靜默**：`Library\.manifests\spork.jdn` 裡**列著** `utf8.dll`、`base64.dll`
那 45 個檔「已安裝」。jpm 認 manifest，看到有就跳過，所以之後每次
`jpm install spork` 都是 no-op。manifest 是安裝**開始時**就寫好的，後面原生模組
失敗並沒有回頭把它改掉。

**根因**：`jpm uninstall spork` 才會把真相吐出來——

```
error: Permission denied: ...\Library\spork\json.dll
  in os/rm [src/core/os.c]
```

**Windows 不准刪除或覆寫「正在被行程載入」的 DLL**。VS Code 的 Janet++ 擴充
跑著一個 `janet -i ...janet-lsp.jimage --stdio`，加上任何開著的 `janet` REPL，
只要它們 `import` 過 spork 就把 `spork\json.dll` 鎖住了。純 `.janet` 檔照抄沒事，
寫到 `.dll` 撞鎖 → 那一整批失敗。

⚠ **不要用 `jpm uninstall` 逼它重裝**：它是**依字母序刪**，刪到 `json.dll` 就死在那，
留下一個被砍掉一半的 spork（`argparse` `cc` `fmt` `http` 全沒了，`json` 之後的還在），
整個專案跟著爛。真的要做請先備份 `Library\spork` 與 `.manifests\spork.jdn`。

**安全的修法**：離線編好再只補缺的那幾顆。缺的那些**還不存在，所以沒有東西鎖它們**，
唯一被鎖的 `json.*` 跳過不碰即可：

```powershell
# 1. 把 jpm 的 git 快取複製出去（別在原地編）
Copy-Item -Recurse "$env:LOCALAPPDATA\Apps\Janet\Library\.cache\git__*spork*" C:\temp\spork-build
cd C:\temp\spork-build
jpm build                                  # mingw 這台八顆全過，見第 00b 篇

# 2. 只複製缺的，跳過 json.*（那顆被 LSP 鎖著）
Get-ChildItem build\spork -File | Where-Object { $_.Name -notlike 'json.*' } |
  Copy-Item -Destination "$env:LOCALAPPDATA\Apps\Janet\Library\spork\" -Force
```

逐顆驗：`janet -e '(import spork/utf8)'`，沒訊息就是好了。

> **這個坑會再犯**：任何含 `declare-native` 的套件、只要有原生模組正被 LSP 或 REPL
> 載入，都會這樣。**判斷方式**：`jpm install X` 沒有輸出 ≠ 成功，一律用
> `janet -e '(import X)'` 驗收。
>
> 對本 repo 的具體影響：**`spork/base64` 也是原生模組**，所以
> `modules/llm-http/media.janet`（圖像 → data URI）在沒補齊的機器上是整支跑不起來的，
> 而錯誤訊息會指到 media.janet 第一行，看起來像模組寫壞了。

## 十三、`./` 相對 import 在「跑檔案」與「REPL 求值」下不一樣

`(import ./transport)` 這種相對 import，`./` 展開成 Janet `module/paths` 裡的 **`:cur:`**，
而 `:cur:` 來自 dynamic binding **`:current-file`** ——「目前這個檔案在哪個目錄」。

**跑檔案時 janet 會幫你設好，所以 cwd 是哪裡都無所謂**（三種都實測過）：

```sh
janet try/main.janet                    # 從 repo 根目錄
cd try && janet main.janet              # 從檔案所在目錄
cd / && janet C:/…/try/main.janet       # 絕對路徑、完全無關的 cwd
```

**REPL／編輯器求值鍵則不會**：

```sh
janet -e '(pp (dyn :current-file))'     # → nil
janet -e '(import ./transport)'         # → could not find module ./transport
```

`:current-file` 是 `nil` 時 `:cur:` 變空字串，`./transport` 就掉回**相對 cwd** 解析，
在 repo 根目錄下當然找不到 `try/transport.janet`。症狀通常不是 import 報錯本身，而是
下一個 form 求值時的 **`unknown symbol tp/post-chat`**，更難聯想。

REPL 裡的解法是求值前先設一次，之後整個 session 都有效：

```janet
(setdyn :current-file "try/main.janet")   # 給「求值的那支檔案」的路徑
```

⚠ 這行**只給 REPL 用**。留在原始碼裡跑 `janet <檔>` 時它會蓋掉 janet 設好的正確值——
同目錄下剛好還是通的，換成子目錄的檔案就會壞，而且壞得莫名其妙。

⚠ **未解**：`janet-lsp`（VS Code Janet++）對 `./` 相對 import 的補全／跳定義**認不出來**，
`tp/` 之後沒有候選字。跑是跑得動，只是編輯器沒有智慧提示。推測是同一個
`:current-file` 問題（LSP 在它自己的 context 裡分析檔案），**但沒有實際驗證過**。
繞法：暫時改成絕對 import，或直接無視。
