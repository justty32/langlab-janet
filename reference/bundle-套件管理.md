# bundle ・ 全部 16 個

[← reference 索引](README.md)

對應教學：[05 jpm 與專案](../docs/05-jpm-與專案.md)、[05e import 與模組路徑](../docs/05e-import-與模組路徑.md)。

> 對著 `root-env` 逐一核過，`bundle/*` 共 16 個。這是 Janet 1.41 **直接內建**的套件機制
> ——不用裝 jpm、不用 Python，`janet` 執行檔本身就會裝套件。

## 它跟 jpm、spork/pm 的分工

| | 是什麼 | 誰提供 | 管什麼 |
|---|--------|--------|--------|
| `bundle/*` | 內建函式 | Janet 執行檔 | 把**本機一個目錄**裝進 syspath、記錄裝了哪些檔、移除時照著清乾淨 |
| `jpm` | 外部 CLI | 另外裝 | 抓 git、編 C、跑測試、產執行檔，再呼叫底層安裝 |
| `spork/pm` | Janet 函式庫 | spork | 在 Janet 裡做 jpm 那些事（抓 git、解依賴），最後也是落到 `bundle/install` |

一句話：**`bundle/*` 是「裝／移除／查」這層，抓原始碼和編譯是上面那層的事。**
所以 `bundle/install` 只吃**本機路徑**，不吃 URL。

## 實測時別動到系統目錄

`bundle/*` 一律對 **`(dyn *syspath*)`** 動手，預設就是 `~/.local/lib/janet`。
要試就先換掉：

```sh
JANET_PATH=/tmp/試玩 janet -e '(bundle/install "./我的套件" :name "mypkg")'
```

也可以在程式裡 `(setdyn *syspath* "/tmp/試玩")`。

## 一個最小的可安裝目錄

目錄裡放一支 `bundle.janet`（或 `bundle/init.janet`），裡面定義鉤子：

```janet
(defn install [manifest &]
  (bundle/add manifest "hi.janet"))
```

裝起來之後 syspath 底下會多兩樣東西：被 `add` 進去的檔（`hi.janet`），
以及帳本 `bundle/<名字>/manifest.jdn` ＋ 來源副本 `bundle/<名字>/init.janet`。

## 鉤子（5 個）

`postdeps` → `clean` → `build` → `install` → `check`，在 `bundle.janet` 裡定義同名函式就會被叫到。
⚠ **`check` 預設不跑**，要 `(bundle/install path :check true)` 才會。
⚠ 安裝中途丟錯的話，Janet 會印 `installation error, uninstalling` 然後**自動回滾**。

## 裝與移除（6 個）

| 函式 | 簽名 | 說明 |
|------|------|------|
| `bundle/install` | `(bundle/install path &keys config)` | 從本機目錄安裝。名字取 `config` 的 `:name`，沒有就讀 info 檔 |
| `bundle/uninstall` | `(bundle/uninstall name)` | 跑 `uninstall` 鉤子，再照 manifest 反向刪檔 |
| `bundle/reinstall` | `(bundle/reinstall name &keys new-config)` | 用**已存檔的那份來源**重裝（先 uninstall 再 install）|
| `bundle/replace` | `(bundle/replace name path &keys new-config)` | 換成**另一個目錄**的版本，但不會弄壞依賴它的套件 |
| `bundle/update-all` | `(bundle/update-all &keys configs)` | 全部重裝一遍 |
| `bundle/prune` | `(bundle/prune)` | 清掉所有「標了 `:auto-remove` 又沒人依賴」的套件 |

`:auto-remove true` 是給「因為別人要才順便裝」的相依套件用的標記，`bundle/prune` 認這個。

## 查（5 個）

| 函式 | 回什麼 |
|------|--------|
| `bundle/list` | 所有已安裝套件的名字，字典序 |
| `bundle/topolist` | 同一批但排成**拓樸序**：每個套件都排在它的相依之後 |
| `bundle/installed?` | 布林 |
| `bundle/manifest` | 那個套件的 manifest table；查不到**丟錯**不是回 `nil` |
| `bundle/whois` | 給一個檔案路徑，回是哪個套件裝的 |

manifest 的鍵：`:name` `:files`（**絕對**路徑清單）`:hooks`（有定義哪些鉤子）
`:local-source`，以及你在 `config` 裡傳進去的東西（例如 `:auto-remove`）。
⚠ `bundle/whois` 吃的是**真的存在的路徑**，檔案不在會丟 `No such file or directory`。

## 安裝腳本裡才能用的（5 個）

這幾個第一個參數都是 `manifest`，只有在 `install` 鉤子裡叫才有意義——
它們一邊複製檔案一邊把路徑記進帳本，這樣 uninstall 才刪得乾淨。

| 函式 | 簽名 | 說明 |
|------|------|------|
| `bundle/add` | `(bundle/add manifest src &opt dest mode)` | 檔案或**整個目錄**都吃 |
| `bundle/add-file` | `(bundle/add-file manifest src &opt dest mode)` | 只吃單檔 |
| `bundle/add-directory` | `(bundle/add-directory manifest dest &opt mode)` | 建一個空目錄 |
| `bundle/add-bin` | `(bundle/add-bin manifest src &opt filename mode)` | 放進 syspath 的 `bin/`，預設設成可執行 |
| `bundle/add-manpage` | `(bundle/add-manpage manifest src &opt mansec)` | 放進 `man/<mansec>/`，預設 `man1` |

⚠ `bundle/add-directory` **不會自動建上層目錄**：直接 `"share/mypkg"` 會丟
`No such file or directory`，要先 `(bundle/add-directory manifest "share")`。
⚠ 裝了 `bin/` 的東西時 Janet 會提醒 `executable files have been installed to …`
——那個目錄**不會自己進 PATH**。
