# 缺口記錄

使用者練習 Janet 時，若詢問的東西在這個資料夾（janet-lab）目前沒有涵蓋，記在這裡。
之後交給另一個 agent 依此補完。**只記缺口，不記已解決的問答；補完就從這裡移除。**

格式：`- [日期] 使用者問了什麼 / 目前資料夾沒有涵蓋的地方 → 建議補在哪`

---

## 目前沒有 open 的缺口

2026-08-04 把先前累積的十筆全部補完了，對應產出如下（留著當索引，不是待辦）：

| 原缺口 | 補在哪 |
|--------|--------|
| `jpm new-project` 等三個 scaffold 指令 | [docs/05b](docs/05b-建立新專案.md) |
| top-level `main` 會被自動呼叫的規則 | [docs/05b](docs/05b-建立新專案.md)（含 `use` 污染、頂層程式碼比 main 早跑兩個後果） |
| `jpm run` 是 make 式 rule runner、`phony` 自訂 rule | [docs/05c](docs/05c-jpm-的-rule-系統.md) |
| `jpm build` 不會因為改了非入口檔就重編 | [docs/05c](docs/05c-jpm-的-rule-系統.md) |
| 引用自己另一個本地專案（相對路徑／`jpm install` 本地 repo 的兩個前提） | [docs/05d](docs/05d-引用自己的專案.md) |
| `~` 是 quasiquote 不是家目錄、import 不帶副檔名 | [snippets/import-files/main.janet](snippets/import-files/main.janet)（跑起來會印出 `(quasiquote /repo/x)`）＋ [modules/README.md](modules/README.md) 規則 ④⑤ |
| spork/http 當 client 打 API：POST、buffer／status、無 TLS、無串流 | [docs/17](docs/17-用-spork-http-打-api.md) |
| 一份 chat completion 回應該檢查什麼（`finish_reason`／空字串 content） | [docs/17](docs/17-用-spork-http-打-api.md) ＋ [FINDINGS-踩坑.md](FINDINGS-踩坑.md) 第十節 |
| `spork/json` 的 unicode 逃逸、`keywords` 參數忘了給會靜默全 nil | [docs/03](docs/03-json.md) |
| `+` 只吃數字、字串串接要用 `string` | [docs/02](docs/02-資料結構.md) ＋ [docs/01](docs/01-語言速成.md) 指路 |
| `dyn` 到底是什麼（原本只列了 API，沒解釋概念） | [docs/12c](docs/12c-dyn.md)——含跟 Lua 全域變數／CL special variable 的對照 |

---

## 怎麼系統性找缺口（不用等使用者問）

上面那十筆是**被動**記下來的（使用者問了才發現沒寫）。要**主動**找，就拿 `root-env`
的全部綁定去對 `docs/` 掃一遍——沒被任何一篇提到的，就是候選缺口：

```sh
janet -e '(each s (sort (map string (filter symbol? (keys root-env)))) (print s))' > /tmp/all.txt
cat docs/*.md > /tmp/alldocs.txt
while read f; do grep -qF -- "$f" /tmp/alldocs.txt || echo "$f"; done < /tmp/all.txt
```

同一招換成 `(filter |(string/has-prefix? "os/" (string $)) …)` 就能只掃某一個家族。

**2026-08-30 掃過一輪**：702 個綁定裡零覆蓋的從 34 個降到 **18 個**，補出了
[32](docs/32-條件與模式比對.md)～[40](docs/40-內建動態變數.md) 九篇。

剩下的 18 個**刻意不補**，因為它們不是寫 Janet 會用到的東西：

| 剩下的 | 為什麼不補 |
|--------|-----------|
| `%=` `*=` | 複合指定運算子，`+=`／`-=` 已在 [01](docs/01-語言速成.md) 教過，同一個模式 |
| `*lint-error*` `*lint-levels*` `*lint-warn*` `*flychecking*` | 給 linter／IDE 整合用，不是寫程式時碰的 |
| `*macro-form*` `*macro-lints*` `*defdyn-prefix*` | 巨集展開器的內部狀態（[08](docs/08-巨集-macro.md) 教的是寫巨集，不是改展開器）|
| `*module-loaders*` `*module-loading*` `*module-make-env*` | 自訂模組載入器；要動這層的人不需要入門教學 |
| `*ffi-context*` `*peg-grammar*` `*profilepath*` `*err-color*` `*task-id*` | 各自模組的內部旗標，[10b](docs/10b-ffi-型別與指標.md)／[14](docs/14-peg.md)／[15](docs/15-ev-channel-net.md) 講的是用法不是內部 |

> ⚠ 「零覆蓋」只代表**沒有任何一篇提到那個名字**，不代表該補。
> 判斷要不要補的標準是「**寫 Janet 的人會不會撞到它**」，不是把數字歸零。

## 新的缺口記在下面
