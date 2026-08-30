# charts ・ 圖表產生（CPU 繪製到點陣圖）

[← spork 索引](README.md)｜[← reference 索引](../README.md)

`spork/charts` 在 CPU 上把資料畫成折線圖／長條圖／散佈圖／熱力圖／treemap，輸出 `spork/gfx2d` 的點陣圖（可存成 PNG）。**完全不需要視窗或 GPU**——本檔所有範例都真的存出了 PNG 檔並用 `file` 指令驗證過格式。作者自己標注這模組是 beta，API 可能會變。全部範例皆以 `janet -e` 實測於 Janet 1.41.2。

「資料框」（data-frame）指一個 table，key 是欄名（keyword 或任意值），value 是那一欄的數字陣列，例如 `{:month [1 2 3] :temp [12 15 18]}`。

## 動態變數（樣式預設值，7 個）

| 變數 | 說明 |
|---|---|
| `*font*` | 預設字型 |
| `*text-color*` | 標題／座標軸文字顏色 |
| `*stroke-color*` | 邊框等線條顏色 |
| `*background-color*` | 背景色 |
| `*grid-color*` | 格線顏色 |
| `*padding*` | 預設留白像素 |
| `*color-seed*` | 挑偽隨機顏色用的隨機種子 |

`(dark-mode)` / `(light-mode)`：一次把上面幾個顏色類變數設成深色／淺色主題預設值，回傳 `nil`。

## 顏色與色階

| 函式 | 簽名 | 說明 |
|---|---|---|
| `color-lerp` | `(color-lerp a b t)` | 兩色之間線性內插（`t` 為 0~1） |
| `make-color-map` | `(make-color-map & colors)` | 給一串顏色，回傳一個 `(fn [t] color)` 的漸層色階函式 |
| `invert-color-map` | `(invert-color-map mapping)` | 把色階函式反過來（`t` 換成 `1-t`） |
| `to-color-map` | `(to-color-map cmap)` | 把 keyword／function／array／dict／number 統一轉成色階函式 |
| `color-maps` | table | 內建色階：`:hash` `:hash-label` `:grayscale` `:bluescale` `:redscale` `:greenscale` 及對應 `-black` 版、`:turbo` `:magma` `:viridis` |

## 座標軸與圖例

| 函式 | 簽名 | 說明 |
|---|---|---|
| `draw-axes` | `(draw-axes &named canvas width height ... x-min x-max y-min y-max ...)` | 畫出座標軸格線與刻度，回傳 `[view convert unconvert canvas]`：`view` 是扣掉座標軸後可畫圖的子畫布，`convert` 把資料座標轉成像素座標 |
| `draw-legend` | `(draw-legend canvas &named ... labels color-map ...)` | 畫圖例（顏色對標籤），回傳 `[w h]` |
| `draw-heat-legend` | `(draw-heat-legend canvas &named ... color-map labels ...)` | 畫熱力圖用的漸層色條圖例 |

## 畫圖表

| 函式 | 簽名 | 說明 |
|---|---|---|
| `plot-line-graph` | `(plot-line-graph &named canvas data to-pixel-space x-column y-column ...)` | 只畫線／點，不含座標軸；要配合 `draw-axes` 的 `convert` 當 `to-pixel-space` |
| `line-chart` | `(line-chart &named width height data x-column y-column title save-as ...)` | 高階版：座標軸＋畫線＋圖例一次做完，支援 `:save-as` 直接存檔 |
| `plot-heat-map` | `(plot-heat-map &named canvas color-fn num-columns num-rows ...)` | 只畫熱力格子，不含座標軸／圖例 |
| `heat-map-chart` | `(heat-map-chart &named width height color-fn cell-text-fn num-columns num-rows save-as ...)` | 高階版熱力圖，`color-fn` 是 `(fn [x y] color)` |
| `plot-packing-chart` | `(plot-packing-chart &named canvas width height data-map ...)` | Treemap（面積比例圖），圓餅圖的替代方案，`data-map` 是 `{類別 數值}` |

## 實測：折線圖（低階組合：draw-axes ＋ plot-line-graph）

```
(import spork/charts :as c)
(import spork/gfx2d :as g)
(def data {:x [1 2 3 4 5] :y [2 4 3 5 6]})
(def [view convert unconvert canvas]
  (c/draw-axes :width 200 :height 150 :x-min 0 :x-max 6 :y-min 0 :y-max 7))
(c/plot-line-graph :canvas view :data data :to-pixel-space convert
                    :x-column :x :y-column :y :circle-points true)
(g/save "chart-test.png" canvas)
```
→ 存出 `chart-test.png`，`file` 驗證為 `PNG image data, 200 x 150, 8-bit/color RGBA`。

## 實測：折線圖（高階一次到位）

```
(import spork/charts :as c)
(def data {:month [1 2 3 4 5 6] :temp [12 15 18 22 25 24]})
(c/line-chart :width 300 :height 200 :data data
              :x-column :month :y-column :temp
              :title "溫度" :x-label "月" :y-label "度C"
              :save-as "line-chart-test.png")
```
→ 存出 `line-chart-test.png`（300x200 PNG），回傳值是 `gfx2d/image`。

## 實測：熱力圖（用 color-fn，不用 data-frame）

```
(import spork/charts :as c)
(c/heat-map-chart :width 100 :height 100 :num-columns 5 :num-rows 5
  :color-fn (fn [x y] ((c/to-color-map :viridis) (/ (+ x y) 8)))
  :save-as "heat-test.png")
```
→ 存出 100x100 PNG。

## 實測：Treemap（面積比例圖）

```
(import spork/charts :as c)
(import spork/gfx2d :as g)
(def canvas (g/blank 200 150 4))
(c/plot-packing-chart :canvas canvas :data-map {:a 30 :b 50 :c 20})
(g/save "packing-test.png" canvas)
```
→ 存出 200x150 PNG，三塊面積依 30/50/20 比例分配。

## 實測：色階與圖例

```
(import spork/charts :as c) (import spork/gfx2d :as g)
(c/color-lerp g/black g/white 0.5)      # => 2138535423（灰，介於黑白之間）
(def cmap (c/make-color-map g/red g/green g/blue))
(cmap 0.5)                              # => 4278255360（正好落在綠色，因為三色平分區間，t=0.5 對到中點顏色）
((c/to-color-map :viridis) 0.3)         # => 4282719239

(def canvas (g/blank 200 60 4))
(c/draw-legend canvas :labels ["a" "b" "c"] :color-map :turbo :view-width 200 :frame true)
(g/save "legend-test.png" canvas)       # => 存出 200x60 PNG
```
