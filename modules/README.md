# modules

真的拿來用的小模組（不是教學附件）。每個各自拆檔、各自有 README、各自編出一支執行檔。

| 模組 | 是什麼 | 執行檔 |
|------|--------|--------|
| [`llm-http/`](llm-http/README.md) | 純 Janet 打 OpenAI 相容端點（本機 litellm proxy 或直接打 LM Studio）；**多輪 tool loop**＋**圖像輸入**＋**自訂 endpoint／參數**。內建四筆：`local`／`deepseek`／`claude`／`openrouter` | `build/llm-http` |
| [`pi-shell/`](pi-shell/README.md) | 把非互動 agent CLI（`pi -p`／`claude -p`／**你自己註冊的**）包成子行程的**薄透傳殼** | `build/pi-shell` |

兩個模組共用同一套設計思想：**內建的只是預設值，使用者可以用 registry ＋設定檔加自己的**
（llm-http 加 endpoint、pi-shell 加 agent），設定檔一律**只 parse 不 eval**，
放在 `~/.config/<模組名>/` 底下自動載入，**沒有設定檔是正常狀態、不會報錯**。
範本分別是 [`llm-http/endpoints.example.janet`](llm-http/endpoints.example.janet) 與
[`pi-shell/agents.example.janet`](pi-shell/agents.example.janet)。

能跑的範例在 [`../examples/llm-http/`](../examples/llm-http/)（八支，中文註解）。

兩者都在 [`../project.janet`](../project.janet) 宣告；`jpm build` 一次編出來，`jpm test` 跑
[`../test/`](../test/) 底下對應的離線測試（不打網路、不呼叫真的模型）。

環境與架構的實測背景（為什麼走 litellm proxy）→ [`../FINDINGS.md`](../FINDINGS.md)；
實作時踩到的環境／API 地雷 → [`../FINDINGS-踩坑.md`](../FINDINGS-踩坑.md)、[工具鏈篇](../FINDINGS-踩坑b-工具鏈.md)。

---

# 怎麼 import 這些模組

## 三條規則先記住

**① 相對路徑是相對「寫這行 import 的那支檔案」，不是相對你在哪個目錄下指令。**
這是 Janet 跟很多語言最不一樣的一點。同一行 `(import ../modules/llm-http/init)`，
放在 `test/x.janet` 裡是對的，複製到 `bin/x.janet` 裡也是對的（兩者都在根目錄下一層），
但複製到根目錄的檔案裡就錯了——跟你 `cd` 到哪毫無關係。

**② 相對路徑一定要有 `./` 或 `../` 開頭。** 沒前綴的裸名字（`(import spork/json)`）走
**系統模組路徑**（`(dyn :syspath)` 與 `module/paths`），不會當成你旁邊的檔案。

**③ 絕對路徑不能用。** `(import /home/你/…)` 開頭的 `/` 會被吃掉。真的需要絕對路徑時用
`(dofile "/絕對/路徑.janet")`（但那會繞過模組快取，每次重跑）。

**④ `~` 不是家目錄，是 quasiquote。** `~/repo/x` 被讀成 `(quasiquote /repo/x)` 一個
**tuple**，錯誤訊息長成 `could not find module <tuple 0x...>`——看到 `<tuple>` 就是它。

**⑤ 不要帶 `.janet` 副檔名。** 那是模組名不是檔名，Janet 自己會接 `.janet`／`.so` 去找。

> 更完整的 import 語意（快取、`:prefix`、`merge-module` 挑名字、`dofile` 的差別）
> 見 [`../snippets/import-files/main.janet`](../snippets/import-files/main.janet)，那支跑起來就是一份教材。

## 你的檔案在哪 → 路徑怎麼寫

以 `llm-http` 為例（`pi-shell` 同理，換掉模組名即可）：

| 你的 `.janet` 檔放在 | import 要寫成 |
|---------------------|--------------|
| `test/foo.janet`、`bin/foo.janet`（根目錄下一層） | `(import ../modules/llm-http/init :as llm)` |
| janet-lab 根目錄 `foo.janet` | `(import ./modules/llm-http/init :as llm)` |
| `modules/別的模組/foo.janet`（跟它同一層） | `(import ../llm-http/init :as llm)` |
| 完全不同的 repo，例如 `~/code/我的專案/foo.janet` | `(import ../../repo/langs/janet-lab/modules/llm-http/init :as llm)`（自己數幾層 `../`） |

跨 repo 那條要數 `../` 很煩的話，看下面「不想數 `../`」。

## `:as` 跟直接 import 的差別

```janet
(import ../modules/llm-http/init)              # → 前綴是 init/…   ← 通常不是你要的
(import ../modules/llm-http/init :as llm)      # → 前綴是 llm/…     ← 建議這樣
(import ../modules/llm-http/init :prefix "")   # → 不加前綴，ask、endpoint 直接可用
```

**前綴預設取路徑最後一段**，而這些模組的門面檔都叫 `init.janet`，所以不給 `:as`
會變成一堆 `init/ask`、`init/endpoint`——很難讀。**一律給 `:as`。**

## 只要某一層也可以

門面 `init.janet` 只是把底下幾個檔 re-export 出來，你也可以直接 import 個別檔案：

```janet
(import ../modules/llm-http/tools     :as t)    # 只要 tool loop
(import ../modules/llm-http/endpoints :as ep)   # 只要 endpoint（registry ＋設定檔載入）
(import ../modules/llm-http/registry  :as reg)  # 再往下一層：只要 registry 行為，不碰檔案系統
(import ../modules/llm-http/chat      :as conv) # 只要對話語意，不管 endpoint 是誰給的
(import ../modules/pi-shell/proc      :as proc) # 只要子行程管線，不帶 agent 知識
```

⚠ **`init.janet` 與 `endpoints.janet`／`pi-shell/init.janet` 有一個副作用**：
會自動探測一次使用者的設定檔。想要「純函式、零 IO」的那一層，就直接 import
`registry.janet`／`agents.janet`——它們不會去碰檔案系統。

## ⚠ import 一定要放在**頂層**

`import` 是**編譯期**就要生效的，塞進函式裡等執行才跑，那時候用到它的程式碼早就編譯失敗了。

```janet
(defn 壞例子 []
  (import ../modules/llm-http/init :as llm)    # ✗ 不要這樣
  (llm/ask …))
```

## 不想數 `../`：裝起來用裸名字

`project.janet` 裡兩個模組都有 `declare-source`（prefix 分別是 `llm-http`、`pi-shell`），
所以**裝進模組樹之後**就能用不帶路徑的裸名字 import，跟 `spork/json` 一樣：

```sh
cd ~/repo/langs/janet-lab
jpm install                 # 裝到全域 ~/.local/lib/janet/
# 或裝到某個專案自己的 jpm_tree（不動全域）：
cd ~/code/我的專案 && jpm -l install git::file:///home/lorkhan/repo/langs/janet-lab
```

```janet
(import llm-http/init :as llm)      # 裝好之後，放在哪一層都這樣寫
(import pi-shell/init :as agent)
```

> ⚠ `jpm install` 從本地 repo 裝有兩個前提：**要先 `git init` ＋至少一個 commit**，而且
> bundle 字串**必須含冒號**才會被當成位址（`git::file:///絕對路徑`）——直接給目錄或
> `./相對路徑` 會被當成官方套件清單的短名字，回你 `bundle ... not found`。

**開發期建議還是用相對路徑**：改了模組馬上生效，不用每次重裝。

## 兩個模組的最小可跑範例

```janet
(import ../modules/llm-http/init :as llm)
(import ../modules/pi-shell/init :as agent)

# llm-http：一行式問答（需要 litellm proxy 已經起著，見它的 README）
(def cfg (llm/endpoint "local"))
(print (llm/ask cfg "台灣最高的山是哪座？"))

# pi-shell：跑一支 agent CLI（⚠ 它們預設能動你的檔案，自己決定要不要限制）
(def r (agent/run-pi ["--no-tools" "只回一個字 ok"]))
(print (r :out) (r :code))
```

自訂自己的 endpoint／agent：

```janet
# llm-http：三種寫法，都不必改 repo 原始碼
(llm/endpoint {:model "qwen3" :url "http://127.0.0.1:1234/v1/chat/completions"})  # inline
(llm/define-endpoint "qwen" {:model "qwen3" :params {:temperature 0.2}})          # 註冊
(llm/load-endpoints! "~/.config/llm-http/endpoints.janet")                        # 設定檔

# pi-shell：同一套形狀
(agent/define-agent "qwen-cli" {:cmd "qwen" :model-flag "-m"})
(agent/run-agent "qwen-cli" ["回 ok"])
```

各自完整的 API 與旗標見兩個模組自己的 README。
