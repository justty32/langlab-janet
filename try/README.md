# try · 從零蓋一個 LLM 客戶端（過程紀錄）

跟其他資料夾的差別：`docs/` 是**一次講一個主題**、`snippets/` 是**一段一段抄**，
這裡是**一個真東西從零長出來的過程**——「先寫得會動，再看它為什麼該長成這樣」。

四支檔，一百多行，但每個設計決定都寫了**為什麼**在註解裡。要看「怎麼把一個程式
分層」而不是「某個函式怎麼用」時，讀這裡。

> 這是**過程**不是成品。成品在 [`modules/llm-http/`](../modules/llm-http/README.md)
> ——17 支檔、有測試、有 CLI。兩邊對照著看，就看得出「小東西長大時會分裂成什麼」。

## 四支檔

| 檔 | 是什麼 | 行數 |
|----|--------|------|
| [`transport.janet`](transport.janet) | **最底層**：HTTP 怎麼送、JSON 怎麼收、錯誤怎麼分類。不知道「對話」是什麼 | 26 |
| [`llm.janet`](llm.janet) | **對話層**：一個 bot ＝ 一段對話。system 擺哪、history 何時寫、答案從哪挖 | 96 |
| [`main.janet`](main.janet) | 最小的「打得通嗎」——直接呼叫 transport，跳過對話層 | 13 |
| [`test-llm.janet`](test-llm.janet) | 第 2 步的驗收：記憶、reset、失敗不污染 history、`remember=false` | 33 |

```sh
janet try/main.janet        # 只驗「打得通」
janet try/test-llm.janet    # 驗對話記憶那幾條
```

⚠ **兩支都要 litellm proxy 在 `127.0.0.1:4000` 跑著**（怎麼起見
[`FINDINGS.md`](../FINDINGS.md)）。所以它們**不在 `jpm test` 裡**——
本 repo 的測試一律離線（見 [docs/23](../docs/23-測試怎麼寫.md)）。

## 分層是這裡最重要的一課

```
llm.janet        只管語意：system 擺哪、history 何時寫、答案在哪
   ↓ 呼叫
transport.janet  只管管線：URL、header、JSON、錯誤分類
```

`transport` **不知道「對話」是什麼**，`llm` **不碰 http 也不碰 json**。
好處在改東西的時候才看得出來：換後端只動下層，改記憶規則只動上層。

順帶一個小設計：`bot` 那張 table **剛好也是 transport 要的 cfg**
（`:url`／`:api-key` 兩個欄位就在裡面），所以 `post-chat` 直接收 `bot`，
不必另外組一份設定物件。

## 五個寫進註解的坑

這幾條都是實際踩過才寫下來的，而且**每一條都對應到 docs 的某一篇**：

| 坑 | 症狀 | 對應教學 |
|----|------|---------|
| `:history` 一定要在 `new` 裡建 | 放進共用的表 → **所有 bot 共用同一個 array**，症狀是「它記得我沒說過的話」 | [22 原型與方法](../docs/22-原型與方法.md) 陷阱② |
| `system` 不佔 `history` | 不然 `reset` 就講不通了——「換話題重來但人設留著」做不到 | — |
| **成功之後才寫 `history`** | 先推 user 再送出的話，失敗會在 history 留下一則**沒有回應的孤兒 user 訊息**，之後每輪都送出去（user, user, assistant…），有些後端直接 400、有些默默答歪 | [20 錯誤處理](../docs/20-錯誤處理與資源管理.md) |
| 存**整則 message table** 不是字串 | 做 tool loop 時 assistant 那則會帶 `:tool_calls`，只存 `content` 就弄丟了 | — |
| `content` 空字串 ＋ `finish_reason=length` | 推理模型把 token 全花在 reasoning 上，**HTTP 仍是 200**。不擋的話呼叫端拿到 `""` 以為模型沒話說 | [17 打 API](../docs/17-用-spork-http-打-api.md)、[FINDINGS-踩坑](../FINDINGS-踩坑.md) 第十節 |

第一條特別值得看：它跟 [docs/22](../docs/22-原型與方法.md) 那個「別把可變的預設值放進
prototype」**是同一個 bug 的兩種穿法**——Janet 沒有值語意複製（[01b](../docs/01b-給-C++-開發者.md)），
所以「共用一個 `@[]`」這件事會從各種角度冒出來。

## 接下來

- 想看這套長大之後的樣子 → [`modules/llm-http/`](../modules/llm-http/README.md)
- 想看它的八支範例 → [`examples/llm-http/`](../examples/llm-http/README.md)
- 想知道為什麼選 litellm proxy、環境有哪些雷 → [`FINDINGS.md`](../FINDINGS.md)
