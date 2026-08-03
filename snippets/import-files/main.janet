#!/usr/bin/env janet
# 「像 C++ #include 那樣引用其他 .janet 檔」——但 Janet 是模組不是文字貼上。
# 跑法：janet snippets/import-files/main.janet
#
# 跟 #include 的四個關鍵差異：
#   1. 不是文字展開，是「跑那支檔、拿它的 env」。所以沒有 include guard 的問題。
#   2. 同一個模組只會被載入一次（快取在 module/cache），重複 import 是免費的。
#   3. 名字預設「有前綴」：(import ./lib/greet) → greet/hello，不會汙染你的命名空間。
#   4. 相對路徑是相對「寫這行 import 的那支檔」，不是相對 cwd。

# ── 1) 基本：相對路徑，前綴自動取檔名 ────────────────────────────────
(import ./lib/math-utils)                 # → math-utils/square
(import ./lib/greet :as g)                # → g/hello        （自己取前綴）
(import ./lib/deep/nested :prefix "deep-") # → deep-deep-cube（自訂前綴）
(import spork/path)                        # 系統模組：沒有 ./ 就走 module/paths

# ── 2) 只挑幾個名字進來（像 using X::y）────────────────────────────
# ★ 必須放在頂層：import / merge-module 是「編譯這一段時」就要生效的，
#   放進函式裡等到執行才跑，那時候 (cube 3) 早就編譯失敗了。
(def math-env (require "./lib/math-utils"))   # require = 載入並回傳 env，不建綁定
(merge-module (curenv) math-env "" true ['cube])   # 只把 cube 併進來、不加前綴

(defn h [s] (printf "\n── %s" s))

(defn main [&]
  (h "三種前綴寫法")
  (printf "  (math-utils/square 7) => %d" (math-utils/square 7))
  (printf "  (g/hello \"Janet\")     => %s" (g/hello "Janet"))
  (printf "  (deep-deep-cube 3)    => %d" (deep-deep-cube 3))
  (printf "  模組再 import 模組：%s" (g/平方問候 9))

  (h "只要某幾個名字（見檔頭的 merge-module）")
  (printf "  (cube 3) => %d  ← 沒有前綴，因為是挑進來的" (cube 3))

  # ── 3) 私有的東西進不來 ─────────────────────────────────────────
  (h "def- 是私有的")
  (printf "  math-utils/secret 拿得到內部常數 => %d" (math-utils/secret))
  (printf "  但 '內部常數 這個名字 import 不出來 => %q"
          (get (curenv) '內部常數))

  # ── 4) 快取：同一個模組只跑一次 ─────────────────────────────────
  (h "module/cache")
  (printf "  已載入 %d 個模組" (length (keys module/cache)))
  (each k (sort (map string (keys module/cache)))
    (when (string/find "import-files" k)
      (printf "    %s" k)))
  (print "  再 import 一次是免費的（直接回快取那份 env）")

  # ── 5) 執行期動態載入：路徑是算出來的 ───────────────────────────
  (h "執行期才決定要載哪支")
  (def which "math-utils")
  (def dyn-env (require (string "./lib/" which)))
  (printf "  (require \"./lib/%s\") 的 VERSION = %s"
          which ((get dyn-env 'VERSION) :value))

  # ── 6) 真的要「文字貼上」時：dofile ──────────────────────────────
  (h "dofile：跑一支檔、不走模組快取")
  # dofile 吃的是「檔案系統路徑」，跟 import 的模組路徑規則無關，
  # 所以要自己從 (dyn :current-file) 算出目錄
  (def 這支檔的目錄 (path/dirname (dyn :current-file)))
  (def once (dofile (path/join 這支檔的目錄 "lib" "math-utils.janet")))
  (printf "  dofile 拿到的 env 也有 square => %q" (not (nil? (get once 'square))))
  (print "  dofile 每次都重跑（改檔後想重載就用它），import 則吃快取")

  # ── 7) 路徑規則整理 ─────────────────────────────────────────────
  (h "路徑怎麼寫")
  (print "  ./x        相對「這支檔」所在目錄")
  (print "  ../x       上一層")
  (print "  x  或 a/b  系統模組，走 module/paths + (dyn :syspath)")
  (print "  ★ (import /abs/path) 不能用——開頭的 / 會被吃掉，")
  (print "     絕對路徑請用 (dofile \"/abs/path.janet\")")
  (printf "  這支檔自己是：%s" (dyn :current-file))
  (print))
