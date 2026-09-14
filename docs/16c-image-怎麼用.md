# 16c · image 怎麼用

[← 16b image：存成檔](16b-image-存成檔.md)｜下一篇：[16d image 與 jpm](16d-image-與-jpm.md)

手上有一個 `.jimage` 之後，四種用法：

| 想做什麼 | 寫法 | 拿到什麼 |
|----------|------|----------|
| 當程式跑 | `janet -i x.jimage 參數…` | 呼叫裡面的 `main` |
| 當模組用 | `(import ./x)` | `x/foo`；**自動找 `.jimage`** |
| 在那個環境裡開 REPL | `janet -l ./x -r` | 裡面的名字不加前綴直接用 |
| 自己翻 | `(load-image (slurp "x.jimage"))` | 一張 env table |

## `janet -i`：當程式跑

只做一件事：讀 env，有 `main` 就用命令列參數呼叫它。頂層不會再跑一次（[16b](16b-image-存成檔.md)）。

```
$ janet -i args.jimage p q
main 收到 ("args.jimage" "p" "q")；(dyn :args) = @["args.jimage" "p" "q"]；:current-file = "args.janet"
```

`main` 的參數與 `(dyn :args)` 都是**這次**的；`:current-file` 則還是編譯時的原始檔名。
沒有 `main` 就靜靜結束，exit 0。

⚠ `-i` 不能省。`janet x.jimage` 會把二進位當原始碼 parse：
`x.jimage:1:2: parse error: invalid utf-8 in symbol`。反過來 `janet -i x.janet` 也不行：
`expected array, table or buffer, got 40`（`(` 的 ASCII 碼）。檔案壞了是 `unexpected end of source`。

## `import`：當模組用

`module/paths` 裡 `.jimage` 排在 `.janet` 前面（[40](40-內建動態變數.md) 印過那張表），
所以 `(import ./mod)` 會**先找 `mod.jimage`**，找到就不看 `mod.janet`。

⚠ **它不比時間戳。** 實測：

```
$ janet -c mod.janet mod.jimage      # 此時 version = :v1
$ sed -i 's/v1/v2/' mod.janet        # 改原始碼
$ janet -e '(import ./mod) (print mod/version)'
v1                                   ← 拿到的還是 image
```

`module/cache` 記的 key 是 `"mod.jimage"`，一眼就看得出載到哪個。
開發期別讓 `.jimage` 跟 `.janet` 躺在同一個目錄，這種「改了沒反應」跟
[05c](05c-jpm-的-rule-系統.md) 那個 `jpm build` 不重編一樣惡毒。

## `-l` ＋ `-r`：回到存檔時的 REPL

`-l` 是「處理後面的參數前先 import 一個模組，**不加前綴**」；`-r` 是「跑完進 REPL」。
接上 16b 存的 `repl.jimage`：

```
$ janet -q -l ./repl -r
(add "third")
notes                ;=> @["first" "second" "third"]
```

⚠ 單獨 `janet -r -i x.jimage` **不會**讓 REPL 看到 image 裡的東西——`-i` 跑完 `main`，
REPL 另開一張新 env，打 `counter` 會說 `unknown symbol`。程式裡要掉進去用
`(repl nil nil (load-image (slurp "x.jimage")))`（`repl` 第三個參數是 env，見 [`snippets/repl-mode`](../snippets/repl-mode.janet)）。

## `load-image`：自己翻

回傳的就是一張 env table，結構同 [12](12-env-環境與動態變數.md)：

```janet
(def env (load-image (slurp "snap.jimage")))
(def bump (get-in env ['bump :value]))     # 取函式
(bump)                                     ;=> 4   接著存檔時的 n=3 往下數
(get-in env ['counter :value])             ;=> @{:n 4}   同一個 table，bump 改的就是它
```

`load-image` 對純資料也能用（`(make-image @{:x 1})` 讀回 `@{:x 1}`），
但那只是 marshal 換個名字，真的存資料看 [16](16-marshal-與自省.md) 的 marshal vs JSON 表。

## image 把純 Janet 依賴帶著走

```janet
# carry.janet
(import spork/path)
(defn main [&] (print (path/join "a" "b" "c.txt")))
```

把 syspath 指到一個空目錄再跑：

```
$ janet -m ./empty -i carry.jimage
a\b\c.txt
$ janet -m ./empty carry.janet
error: could not find module spork/path: …
```

`spork/path` 整個模組 env 已在 image 裡（72 bytes 的原始碼變 10464 bytes，
`path.janet` 本身 9934 bytes）。**能帶走的只有純 Janet**：16b 那個執行期 `require` native 的寫法，
到了空目錄一樣 `could not find module spork/json`。

載入時間：`janet -i big.jimage`（含 argparse／path／schema／htmlgen／temple）24 ms，
跟 `janet -e ''` 空跑一樣；直接跑 `big.janet` 35 ms。省下的是 parse＋compile，不多但穩定。

## 真實案例：janet-lsp

VS Code 的 Janet++ 擴充帶的就是一個 image，不裝任何套件就能跑：

```
$ janet -i …/dist/janet-lsp.jimage --stdio      # 擴充實際下的指令
```

205 KB，翻開來 130 個 symbol、有 `main`，argparse 等依賴全內嵌。
它也是 [FINDINGS-踩坑b](../FINDINGS-踩坑b-工具鏈.md) 裡鎖住 `spork\json.dll` 的那個行程。

---

可跑範例：`janet examples/image-tour.janet`。可抄：[`snippets/checkpoint/`](../snippets/checkpoint/main.janet)。
下一篇 [16d image 與 jpm](16d-image-與-jpm.md)。回目錄：[主題索引](主題與-spork-索引.md)。
