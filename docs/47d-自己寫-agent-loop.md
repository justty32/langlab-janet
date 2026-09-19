# 47d · 自己寫一個 agent loop

**agent 就是一個 while。** 問模型 → 它要工具就執行 → 把結果餵回去 → 再問，
直到它不要工具為止。沒有別的。

前一篇：[47c tool calling 白話](47c-tool-calling.md)。
可跑範例（離線）：[`../examples/agent-tutorial/47d-agent-loop.janet`](../examples/agent-tutorial/47d-agent-loop.janet)。

## 十七行

```janet
(defn 跑一輪到底 [cfg 歷史 tools handlers &opt 上限]
  (default 上限 8)
  (var 答 nil)
  (var 輪 0)
  (while (< 輪 上限)
    (++ 輪)
    (def msg (llm/reply-message (llm/chat cfg 歷史 :tools tools)))
    (array/push 歷史 msg)                       # 整則原樣接回去，含 tool_calls
    (def calls (get msg :tool_calls))
    (if (or (nil? calls) (empty? calls))
      (do (set 答 (get msg :content)) (break))   # 沒要工具 → 這就是答案
      (each c calls
        (def args (json/decode (get-in c [:function :arguments]) true))
        (def r ((get handlers (get-in c [:function :name])) args))
        (array/push 歷史 @{:role "tool"
                           :tool_call_id (get c :id)
                           :content (string (json/encode r))}))))
  [答 輪])
```

跑起來（範例第 ① 段）：

```
答案 = 查到了：{"city":"Taipei","temp_c":31}
打了 2 輪，歷史 4 則：user → assistant → tool → assistant
```

「一輪」＝**打一次模型**。要一次工具就是兩輪：第一輪它要工具，第二輪它作答。

## 這十七行故意少做的三件事

上面那段能跑，但拿去接真模型會踩三個坑。`with-tools`（[`modules/llm-http/tools.janet`](../modules/llm-http/tools.janet)）
補的就是這三件事：

### ① `max-rounds`：模型鬼打牆時要停得下來

真模型會發生「一直要工具、永遠不作答」——參數傳錯、工具回了它看不懂的東西、
或單純在繞圈。**沒有上限的 while 會一直打下去，真模型上就是一直燒錢。**

```
模型永遠不作答時：rounds=3 exhausted=true text=nil
```

`with-tools` 撞到上限時回 `:exhausted true`、`:text nil`，**不丟例外**——
呼叫端自己決定要重試、換提示，還是把半成品交出去。

### ② `handlers` 裡沒有的工具名

上面那段寫的是 `((get handlers 名字) args)`，模型捏一個工具名出來就是 `nil` 被當函式呼叫，
整條 loop 當場掛掉。正確做法見 [47c](47c-tool-calling.md)：**錯誤訊息當工具結果送回去。**

### ③ `trace`：看得到它在幹嘛

不印出來的話，你只會看到「跑了五秒，回一句話」。加個回呼就有了：

```
  trace：模型要 get_weather @{:city "Taipei"} → {"city":"Taipei","temp_c":31}
```

## 換成 with-tools

```janet
(def out (llm/with-tools cfg
                         @[@{:role "user" :content "What is the weather in Taipei?"}]
                         tools handlers
                         :system "你只回一句話。"
                         :max-rounds 8
                         :trace (fn [n args r] (printf "  trace：模型要 %s %j → %s" n args r))))
```

回一張表：

```
答案 = 查到了：{"city":"Taipei","temp_c":31}
rounds = 2  exhausted = false  歷史 5 則（多了那則 system）
roles = system → user → assistant → tool → assistant
```

| key | 是什麼 |
|-----|--------|
| `:text` | 最終答案；撞到上限時是 `nil` |
| `:messages` | 完整歷史，**可以直接拿去接下一輪對話** |
| `:rounds` | 實際打了幾次模型 |
| `:exhausted` | 是不是撞上限才停的 |

⚠ `with-tools` **不會就地改動你傳進去的 `messages`**，它內部複製一份。
要延續對話請接 `(out :messages)`，不是看原來那個陣列。

⚠ `:system` 只在歷史第一則不是 system 時才插進去（[47b](47b-多輪對話.md) 提過）。

## 那再往上一層呢

真正的 agent 還要：記憶與歷史截斷、工具權限與確認、平行叫多個工具、失敗重試、
把任務拆成子任務。這些不是 API 的一部分，是**你的程式**要做的決定——
`with-tools` 只負責把四步的迴圈轉起來。

更完整的封裝見 [`../modules/agent/README.md`](../modules/agent/README.md)——同一個迴圈加上工具箱、記憶截斷與 trace。

下一步：[47e 圖像輸入](47e-圖像輸入.md)——content 從一個字串變成一個陣列。
