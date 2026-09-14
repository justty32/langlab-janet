# 16b · image：把執行中的環境存成檔

[← 16 marshal 與自省](16-marshal-與自省.md)｜下一篇：[16c image 怎麼用](16c-image-怎麼用.md)

image 就是 **marshal 過的 env**。[16](16-marshal-與自省.md) 講過 marshal 存閉包要給查找表，
image 只是把那張表固定下來：

```janet
(def env @{'greeting @{:value "哈囉"}})
(= (string (make-image env)) (string (marshal env make-image-dict)))   # => true
```

`make-image-dict` 是 `(invert (env-lookup root-env))`——692 筆「core 的東西 → 名字」。
所以 image 裡**不含 core**，`print`、`map` 這些都只存名字，讀回時去 root-env 找。
這也是為什麼它綁 Janet 版本：名字對得上、bytecode 格式也得對得上。

## 三條路做出 image

### 1. `janet -c 原始碼 輸出`：從檔案編

```janet
# hello.janet
(print "載入時印這行")
(def greeting "哈囉")
(defn main [& args] (printf "%s，args = %q" greeting args))
```

```
$ janet -c hello.janet hello.jimage
載入時印這行                      ← 頂層在「編」的時候就跑了一次
$ janet -i hello.jimage x y
哈囉，args = ("hello.jimage" "x" "y")   ← 只呼叫 main，頂層不再跑
```

⚠ **頂層的副作用發生在 `-c` 那一刻，不是每次 `-i`**。`(def built-at (os/time))` 放頂層，
image 裡存的就是編譯當時的秒數；實測編完等 3 秒再 `-i`，印出 `差=3 秒`。
要每次執行都算的東西放進 `main`。

### 2. 程式跑到一半，`(make-image (curenv))`

```janet
(def counter @{:n 0})
(defn bump [] (++ (counter :n)))
(bump) (bump) (bump)
(defn main [&] (printf "n=%d" (counter :n)))
(spit "snap.jimage" (make-image (curenv)))     # 451 bytes
```

```
$ janet -i snap.jimage
n=3
```

讀回來翻一翻，env 裡的東西長這樣（怎麼翻見 [16c](16c-image-怎麼用.md)）：

```janet
(def env (load-image (slurp "snap.jimage")))
(sort (keys env))   ;=> @[bump counter main :args :current-file :source]
(env 'counter)      ;=> @{:source-map ("snap.janet" 2 1) :value @{:n 3}}
```

每個 symbol 對到一張 `@{:value … :source-map …}`，跟 [12](12-env-環境與動態變數.md) 講的一樣。
`:args`／`:current-file` 也被一起存了，是存檔當時的值。

⚠ **`janet -e` 裡別這樣做**：`-e` 直接在 root-env 跑，`(make-image (curenv))` 只有 10 bytes，
因為整張 env 都在查找表裡、全變成一個名字。要存就寫成檔案跑。

### 3. 在 REPL 裡存

```
$ janet -q
(def notes @["first"])
(defn add [s] (array/push notes s))
(add "second")
(spit "repl.jimage" (make-image (curenv)))
```

下次 `janet -l ./repl -r` 就回到這個狀態，`notes` 與 `add` 都在（見 16c）。

## 暫停中的 fiber 也存得下

image 存的是 env，env 裡放什麼都行——包括一個 `yield` 到一半的 fiber：

```janet
(defn work [] (var acc 0) (for i 0 10 (+= acc i) (yield [i acc])))
(def job (fiber/new work))
(for _ 0 4 (pp (resume job)))                       # (0 0) (1 1) (2 3) (3 6)
(spit "job.jimage" (make-image @{'job @{:value job}}))
```

另一個行程：

```janet
(def job (get-in (load-image (slurp "job.jimage")) ['job :value]))
(fiber/status job)   ;=> :pending
(resume job)         ;=> (4 10)
(resume job)         ;=> (5 15)
```

閉包裡的 `acc`、呼叫堆疊、程式計數器全在。做 checkpoint 不必把工作改寫成狀態機，
可抄的版本在 [`snippets/checkpoint/`](../snippets/checkpoint/main.janet)。

## 存不了的東西

| 放進 env 的 | 結果 |
|-------------|------|
| 開著的 file／socket／stream | `cannot marshal file in safe mode` |
| native 模組的函式（`spork/json`、`rawterm`…） | `no registry value and cannot marshal <cfunction json/decode>` |
| 純 Janet 的 spork 模組（`path`、`argparse`、`schema`…） | 沒事，整個模組 env 一起進 image |

第二列**最常撞**：`janet -c` 一支頂層 `(import spork/misc)` 的檔會直接失敗，
因為 `misc` 拉進 `rawterm`（native）。哪些是 native 看 [27](27-spork-全覽.md)。

解法是**執行期才載入**，image 只存「載入這件事」不存函式本身：

```janet
(defn main [&]
  (def json (require "spork/json"))            # 跑的時候才碰 native
  (print ((get-in json ['encode :value]) {:ok true})))
```

```
$ janet -c lazy.janet lazy.jimage && janet -i lazy.jimage
{"ok":true}
```

⚠ 把 `(import spork/json)` 寫進 `main` 裡**不行**：`import` 是巨集，展開後 `json/encode`
這個 symbol 在函式裡查不到（`compile error: unknown symbol json/encode`），
要用 `require` 拿 env 再自己取值。這也是 `jpm build` 要自己處理 native 的原因，見 [16c](16c-image-怎麼用.md)。

---

可跑範例：`janet examples/image-tour.janet`（本篇與 16c 的每個實驗）。
下一篇 [16c image 怎麼用](16c-image-怎麼用.md)。回目錄：[主題索引](主題與-spork-索引.md)。
