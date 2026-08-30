# spork/pm、spork/pm-config ・ 套件管理

[← spork 索引](README.md)｜[← reference 索引](../README.md)

這是 **jpm 底層拿去用的套件管理 API**，不是你平常會直接呼叫的東西——使用者日常打的是
`jpm install foo` 這種 shell 指令；`spork/pm`（連同設定用的 `spork/pm-config`）是 jpm 這個
CLI 工具內部呼叫的 Janet API，你會用到它通常是要寫自己的套件管理工具，或魔改 jpm 的行為。
兩個生僻詞先講白：**bundle** 是 jpm 安裝單位的通稱（可能是一個 git repo、一個 tarball、或本地
路徑）；**lockfile** 是鎖定版本用的清單檔，概念上跟 npm 的 `package-lock.json` 類似。

⚠ 這個模組幾乎所有函式都有真實副作用（連網路、寫磁碟、呼叫 `git`／`tar`／`curl`、安裝套件），
本檔只收**純查詢／轉換、讀環境變數、讀既有檔案**這類安全可以真跑的部分。

會下載／安裝／寫檔案的那一批（`download-bundle`、`pm-install`、`save-lockfile`、
`scaffold-project` 等）**本檔不收**——沒辦法在不動到系統的前提下實測，
寫沒跑過的東西不如不寫。要用請查[官方 repo](https://github.com/janet-lang/spork)。
本 repo 走的是 jpm 那一套，見 [05c jpm 的 rule 系統](../../docs/05c-jpm-的-rule-系統.md)。

## spork/pm：動態變數

| 綁定 | 型別 | 一句話 |
|---|---|---|
| `*gitpath*` | dyn keyword | 抓依賴時要用哪個 `git` 指令，預設 `"git"` |
| `*tarpath*` | dyn keyword | 抓依賴時要用哪個 `tar` 指令，預設 `"tar"` |
| `*curlpath*` | dyn keyword | 抓依賴時要用哪個 `curl` 指令，預設 `"curl"` |
| `*pkglist*` | dyn keyword | 找不到本機 `pkgs` bundle 時，改用哪個套件清單網址 |

## spork/pm-config：環境設定

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `default-pkglist` | 字串常數 | 預設套件清單網址，解析短名稱（如 `"spork"`）時查這裡 |
| `detect-toolchain` | `(detect-toolchain env)` | 從 `env` 或環境變數（`MSVC`／`GCC`／`CLANG`／`CC`）猜目前用哪套編譯工具鏈 |
| `read-env-variables` | `(read-env-variables &opt env)` | 把一批 `JANET_*` 環境變數讀進 `env`（預設 `curenv`），轉成 dynamic 綁定用的 table |
| `print-config` | `(print-config &opt env)` | 把 `env` 目前記錄的設定（連同預設值）印成人看得懂的清單 |

## spork/pm：純查詢／轉換

| 函式 | 簽名 | 一句話 |
|---|---|---|
| `resolve-bundle` | `(resolve-bundle bundle)` | 把任何形式的 bundle 描述（短名稱／URL／`type::url::tag`／table）正規化成 `{:url :tag :type}` |
| `name-lookup` | `(name-lookup bundle-addr)` | 拿正規化後的 bundle 位址，反查它對應本機**已安裝**的 bundle 名稱（純讀本機清單，不連網） |
| `jpm-dep-to-bundle-dep` | `(jpm-dep-to-bundle-dep dep-name)` | 把「jpm 風格的依賴識別字」轉成可以餵給 `bundle/reinstall`／`bundle/uninstall` 的本機 bundle 名稱；查無對應會印警告並回 `nil` |
| `opt-ask` | `(opt-ask key input-options)` | `input-options` 裡 `key` 有值就直接回傳；沒有才用 `getline` 跳出來問使用者 |
| `deftemplate` | `(deftemplate template-name & body)` | 巨集：定義一個 `$name`／`${name}` 風格的字串樣板函式（純字串代換，不碰檔案系統） |

⚠ `resolve-bundle` 對「純短名稱」（例如整串就是 `"spork"`，完全沒有冒號）會觸發
`(require "pkgs")`，找不到已安裝的 `pkgs` bundle 時甚至會遞迴呼叫 `pm-install` 去下載——
**這種輸入不安全，本檔範例一律只示範帶冒號的 URL 或 `type::url::tag` 形式**，這些形式因為
字串裡已經有 `:`，會直接跳過套件清單查詢。

## 實測範例（皆於 Janet 1.41.2 實跑）

```janet
(import spork/pm)
(import spork/pm-config :as pmc)

(dyn pm/*curlpath* "curl")   # => "curl"    預設值，沒人 setdyn 過
(dyn pm/*gitpath* "git")     # => "git"
(dyn pm/*tarpath* "tar")     # => "tar"
(dyn pm/*pkglist* pmc/default-pkglist)
                             # => "https://github.com/janet-lang/pkgs.git"

pmc/default-pkglist          # => "https://github.com/janet-lang/pkgs.git"
```

```janet
(pmc/detect-toolchain @{})              # => :gcc     這台機器上，走到 (os/compiler) 那條分支
(pmc/detect-toolchain @{:toolchain :gcc})
                                         # => :gcc     env 裡已經指定就直接用，不用猜

(def e @{})
(pmc/read-env-variables e)
(pp e)                                  # => @{:is-configured true}   沒設對應環境變數就什麼都不加

(os/setenv "JANET_BUILD_TYPE" "debug")
(os/setenv "VERBOSE" "yes")
(def e2 @{})
(pmc/read-env-variables e2)
(pp e2)  # => @{:build-type :debug :is-configured true :verbose true}

(pmc/print-config e2)
# build dir:  _build
# build type: debug
# curl:       curl
# ...
# verbose:    true
# workers:    16
```

⚠ `print-config` **不會**自己去讀環境變數——它只印你傳給它的 `env` table 裡已經有的值（沒有
就用內建預設字串），要看到環境變數生效，得先手動呼叫 `read-env-variables` 把值灌進同一個
`env` 再傳給它，兩者是分開的步驟。

```janet
(pm/resolve-bundle "https://github.com/janet-lang/spork.git")
# => {:type :git :url "https://github.com/janet-lang/spork.git"}

(pm/resolve-bundle "git::https://example.com/foo.git::v1.2.3")
# => {:tag "v1.2.3" :type :git :url "https://example.com/foo.git"}

(pm/resolve-bundle "tar::https://example.com/foo.tar.gz")
# => {:type :tar :url "https://example.com/foo.tar.gz"}

(pm/resolve-bundle {:url "https://example.com/foo.git" :tag "abc123"})
# => {:tag "abc123" :type :git :url "https://example.com/foo.git"}

(pm/resolve-bundle "git+https://example.com/foo.git")
# => {:type :git :url "https://example.com/foo.git"}     "git+" 前綴會被剝掉

(pm/name-lookup (pm/resolve-bundle "https://github.com/janet-lang/spork.git"))
# => nil    這台機器上安裝的 spork 記錄的 url 跟這個字串對不上，所以查無

(pm/jpm-dep-to-bundle-dep "https://github.com/janet-lang/spork.git")
# => nil，且會印一行到 stderr：
# unable to resolve jpm style dependency "https://github.com/janet-lang/spork.git" to a local bundle

(pm/opt-ask :author {:author "Ada"})    # => "Ada"    有預設值就不會跳出來問

(pm/deftemplate greet "Hello $name, welcome to ${project}!")
(greet {:name "Ada" :project "spork"})
# => "Hello Ada, welcome to spork!"
```
