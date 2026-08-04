# 05c · jpm 的 rule 系統（以及 `jpm build` 什麼時候不重編）

[← 05b 建立新專案](05b-建立新專案.md)｜下一篇：[05d 引用自己的另一個專案](05d-引用自己的專案.md)

## ⚠ `jpm run` 不是 `cargo run`

有 `jpm run`，但它**不是「編完直接執行」**。jpm 骨子裡是一套 **make 式的 rule runner**，
`jpm run X` 的意思是「跑名字叫 X 的 rule」：

```sh
jpm rules          # 列出所有 rule（build／clean／install／test／build/<exe>…）
jpm rule-tree      # 連相依關係一起印，看得出誰依賴誰
jpm run build      # ＝ jpm build
```

所以 `jpm run` 之後**不會幫你執行編出來的東西**。從 cargo／npm 過來的人一定會在這裡
預期落空——`cargo run` 是「build + exec」，`jpm run` 只是「跑一條 rule」。

## 要一鍵編完就跑，自己加一條 phony rule

`project.janet` 裡可以自訂 rule。`phony` 是「不產出檔案、只做事」的那種：

```janet
(phony "run" ["build"]                       # 相依：先跑 build 這條 rule
  (os/execute ["./build/我的工具" ;(dyn :args)] :p))
```

```sh
jpm run run        # 先 build，再執行
```

`rule` 則是「產出某個檔案」的規則，第一個參數是**產物**，jpm 靠比對時間戳決定要不要重跑：

```janet
(rule "build/報表.txt" ["資料.csv"]           # 產物依賴 資料.csv
  (spit "build/報表.txt" (處理 (slurp "資料.csv"))))
```

## ★ `jpm build` 不會因為你改了「非入口」的檔案就重編

**這條每天都會咬人，尤其是多檔模組。** 實測：改了 `modules/llm-http/chat.janet`
之後跑 `jpm build`，它**什麼都沒做**、執行檔的時間戳原封不動、跑起來還是舊行為。

原因就是上面那套時間戳比對：`declare-executable` 產生的 rule
**只把 `:entry` 那一支當相依**，不會去追它 `import` 進來的檔案。`main.janet` 沒動，
rule 就認定產物是最新的。

```sh
jpm clean && jpm build      # 最保險
touch bin/main.janet && jpm build   # 或者戳一下 entry
```

⚠ 這件事最惡毒的地方是**它不報錯**——你會以為是自己的修改沒生效而去亂改程式碼。
看到「明明改了卻沒反應」，先確認執行檔的時間戳：

```sh
ls -la --time-style=+%H:%M:%S build/我的工具
```

（`jpm test` 沒有這個問題：它每次都直接跑 `test/` 底下的原始碼，不經過編譯。
所以開發期用 `janet 檔案.janet` 與 `jpm test`，`build` 留到要交付時再說。）
