# 直接指定 `:url` 與請求參數

[← 回 llm-http README](../README.md)｜前一篇：[自訂 endpoint](自訂-endpoint.md)

## ④ 直接指定 `:url`：繞過 proxy

LM Studio、vLLM、llama.cpp 的 server 本身就是 OpenAI 相容的，
給了 `:url` 就完全不看 `:base`，**也就不需要 litellm 擋在前面**：

```janet
(def lm (llm/endpoint {:model "google/gemma-4-e4b"
                       :url   "http://127.0.0.1:1234/v1/chat/completions"
                       :api-key "lm-studio"
                       :vision? true}))
(llm/ask lm "嗨")
```

```sh
./build/llm-http --url http://127.0.0.1:1234/v1/chat/completions -m qwen3 lmstudio "嗨"
```

**這是很實用的一條路**：本機只想跑 LM Studio 的話，連 python／uv／litellm 都不用裝。
代價是各家 provider 的 wire format 差異就得自己面對（proxy 本來是幫你吸收那個的）。

## 請求參數與合併優先序

低 → 高，後面的蓋前面的：

| # | 來源 | 寫法 |
|---|------|------|
| ① | endpoint 的 `:params` | `(endpoint {:model "…" :params {:temperature 0.2}})` |
| ② | 呼叫端的 `:params` | `(chat cfg msgs :params {:temperature 0.5})`／CLI 的 `--param k=v` |
| ③ | 具名參數 | `:temperature`／`:max-tokens`／`:top-p`／CLI 的 `--temperature` 等 |
| ④ | `:extra` | `(chat cfg msgs :extra {:seed 7})`——原樣併進 payload，**什麼都蓋得掉** |

- `:params`／`:extra` 的 key 是 **payload 原名**（`:max_tokens`）；具名參數是 **kebab-case**（`:max-tokens`）。
- `:model` 與 `:messages` 永遠由 cfg／呼叫端決定，塞進 `:params` 沒用——換 model 請用
  `(endpoint "local" {:model "qwen"})`。
- `temperature 0` 是**有效值**，不會被當成「沒給」。
- `endpoint` 的 overrides 裡，`:params` 與 `:headers` 是**疊加**（同名以 overrides 為準），
  其餘 key 是**取代**。

`build-payload` 是純函式，不連線也能把最終 payload 印出來——
示範見 [`../../examples/llm-http/07-params.janet`](../../../examples/llm-http/07-params.janet)。

