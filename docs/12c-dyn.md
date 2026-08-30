# 12c · 動態變數 dyn

[← 12b 切換 env](12b-切換-env.md)｜回到 [12 env：環境表](12-env-環境與動態變數.md)

## 四、動態變數 dyn / setdyn / with-dyns

### `dyn` 到底是什麼

**一張「當前 fiber 隨身帶著的表」**，key 通常是 keyword。`setdyn` 往裡面寫、`dyn` 讀。

跟 `def`／`var` 的差別是**作用域的形狀**：

| | 誰看得到 |
|---|---|
| `def` / `var` | **語彙作用域**——看你把它寫在哪個括號裡，寫死在原始碼上 |
| `dyn` | **動態作用域**——你呼叫出去的**所有函式**都看得到，不管它們寫在哪 |

```janet
(defn 深處 [] (dyn :verbose))        # 它沒有參數，也沒 import 任何東西

(setdyn :verbose true)
(深處)                                # => true   ← 照樣讀得到
```

**存在的理由**：要把一個設定往下傳給整條呼叫鏈時，不必每一層函式都多加一個參數。
「輸出要印到哪」「現在是不是 debug 模式」「目前這支檔叫什麼」都是這種東西。

### ⚠ 從別的語言過來的人一定會這樣類比一次

「`dyn` 就是全域變數嘛」——**對一半**：ambient、不用當參數傳、任何函式都看得到，
這些確實像。但差在最關鍵的地方：

| Lua | Janet |
|-----|-------|
| `_G` / 全域變數 | **env 表**（`(curenv)`，頂層 `def` 進去的地方）→ [12](12-env-環境與動態變數.md) |
| （沒有對應的東西） | **`dyn`**——動態作用域 ＋ per-fiber |

1. **`with-dyns` 是會自動還原的作用域**，全域變數沒有這種東西——Lua 要自己
   `local old = X; X = new; …; X = old`，而且中途丟例外就還原不了。
2. **per-fiber，不是全程序共享。** Lua 的 global 所有 coroutine 共用一份；
   `dyn` 是新 fiber 建立時繼承一份**拷貝**，之後各改各的。

真要找對照，`dyn` 屬於「**動態綁定**」這一族不是「全域變數」那一族：
最接近的是 Common Lisp 的 special variable（`defvar` ＋ `let` 重綁），
其次是 Clojure 的 `binding`、Python 的 `contextvars`。

### `with-dyns` 才是你平常該用的

直接 `setdyn` 會**一直留著**影響後面所有程式。`with-dyns` 有作用域，離開自動還原：

```janet
(with-dyns [:out @""]        # 把標準輸出換成一個 buffer
  (print "這句被攔下來了"))    # 出了這個括號，:out 自動變回螢幕
```

### ⚠ 兩個要記住的性質

1. **它是 per-fiber 的。** 新 fiber 會**繼承**建立當下那份，但之後各改各的、互不影響。
   所以在 `ev/spawn` 出去的工作裡 `setdyn`，改不到外面。
2. **它是全域可見的隱形輸入。** 好用也危險——函式的行為會隨呼叫者的 `dyn` 改變，
   讀程式碼時看不出來。自己的專案要用就 `defdyn` 宣告一下，至少 `(doc *verbose*)` 查得到。

### API

```janet
(setdyn :myk 1)          # 寫
(dyn :myk)               # 讀 => 1
(dyn :nope :fallback)    # 第二參數 = 預設值
(with-dyns [:myk 9]      # ★ 有作用域的覆寫，離開自動還原
  (dyn :myk))            # => 9
```

自己的專案要用動態變數，宣告一下比較好查：

```janet
(defdyn *verbose* "要不要囉唆")   # *verbose* 這個 symbol 之後就等於 :verbose
(setdyn *verbose* true)
(dyn *verbose*)                   # => true
```

內建常用的（`(all-dynamics)` 可全列）：

| key | 內容 |
|-----|------|
| `:args` | 命令列參數陣列 |
| `:executable` | janet 執行檔路徑 |
| `:current-file` | 目前在跑的檔名 |
| `:source` | 錯誤訊息用的來源名 |
| `:syspath` | 模組根目錄 |
| `:out` / `:err` | 輸出去向（可換成 buffer 來攔截輸出） |
| `:pretty-format` | `pp` 用的格式字串 |

---

下一篇：**[12d · OS 環境變數](12d-os-環境變數.md)**（`os/getenv`、給子行程指定環境、
`JANET_PATH` 的坑，以及這一系列的速查表）。⚠ 那是**作業系統**那個 `PATH`／`HOME`，
跟本篇的 `dyn` 完全無關，只是名字容易混。

## 可跑範例

`janet examples/dyn-vars.janet 引數A 引數B`——內建有哪些動態變數、`*out*` 其實就是
keyword `:out`、把 `print` 導進 buffer，以及**用 fiber 實證 dyn 是 per-fiber 的**。
完整清單見 [40 內建動態變數](40-內建動態變數.md)。
