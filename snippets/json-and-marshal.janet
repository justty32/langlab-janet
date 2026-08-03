#!/usr/bin/env janet
# .json 檔 → hash-map（table），以及把 table 存成檔案的兩條路：JSON 和 marshal。
# 跑法：janet snippets/json-and-marshal.janet
#
# 兩種存檔的取捨：
#   JSON    人看得懂、跨語言、可 diff；但只存得下 JSON 有的型別（key 只能是字串）
#   marshal Janet 原生二進位、快、型別完整（keyword / tuple / struct / 甚至閉包）；
#           但只有 Janet 讀得懂，而且版本相依（換 Janet 版本可能讀不回來）

(import spork/json)

(def tmp (string (or (os/getenv "TMPDIR") "/tmp") "/janet-lab-demo"))
(os/mkdir tmp)
(def json-path    (string tmp "/data.json"))
(def marshal-path (string tmp "/data.jimage"))

(defn h [s] (printf "\n── %s" s))

# ── 1) 把一個 table 寫成 .json 檔 ────────────────────────────────────
(def 資料
  @{:name    "Alice"
    :age     30
    :tags    @["janet" "lisp"]
    :nested  @{:city "Taipei" :zip "100"}
    :active  true
    :score   99.5})

(defn write-json [path data]
  (spit path (json/encode data "  " "\n")))     # 縮排 + 換行 = 好讀好 diff 的版本

(defn read-json
  "讀 .json 成 table。★ 第二個參數 true 一定要給，否則 key 是字串不是 keyword。"
  [path]
  (json/decode (slurp path) true))

# ── 2) marshal：Janet 原生序列化 ────────────────────────────────────
(defn write-marshal [path data]
  (spit path (marshal data)))                   # 回傳 buffer，直接寫二進位

(defn read-marshal [path]
  (unmarshal (slurp path)))

(defn main [&]
  (h "寫 JSON")
  (write-json json-path 資料)
  (printf "  寫到 %s（%d bytes）" json-path (os/stat json-path :size))
  (print "  內容：")
  (each line (string/split "\n" (string/trimr (slurp json-path)))
    (printf "    %s" line))

  (h "讀回來就是普通 table")
  (def 讀回 (read-json json-path))
  (printf "  (讀回 :name)              => %q" (讀回 :name))
  (printf "  (get-in 讀回 [:nested :city]) => %q" (get-in 讀回 [:nested :city]))
  (printf "  型別 => %q，可以直接 put/update" (type 讀回))
  (put 讀回 :age 31)
  (update 讀回 :score |(+ $ 0.5))
  (printf "  改完 => age=%q score=%q" (讀回 :age) (讀回 :score))

  (h "★ 不傳 true 的差別")
  (def 字串key (json/decode (slurp json-path)))
  (printf "  (字串key :name)   => %q   ← keyword 取不到" (字串key :name))
  (printf "  (字串key \"name\")  => %q   ← 得用字串" (字串key "name"))

  (h "寫 marshal（二進位）")
  (write-marshal marshal-path 資料)
  (printf "  %s（%d bytes，JSON 是 %d bytes）"
          marshal-path (os/stat marshal-path :size) (os/stat json-path :size))
  (def 還原 (read-marshal marshal-path))
  (printf "  還原後完全相等？ %q" (deep= 資料 還原))

  (h "marshal 存得下 JSON 存不下的東西")
  (def 進階
    @{:keyword-key  {:這是 :struct}          # struct（不可變）
      :tuple        [1 2 3]                   # tuple（JSON 只會變成 array）
      :buffer       @"位元組"
      :int64        (int/s64 "9007199254740993")
      :closure      (fn [x] (* x 2))})        # ★ 連函式都存得下
  (def p2 (string tmp "/adv.jimage"))
  (spit p2 (marshal 進階))
  (def r2 (unmarshal (slurp p2)))
  (printf "  tuple 還是 tuple？   %q" (type (r2 :tuple)))
  (printf "  struct 還是 struct？ %q" (type (r2 :keyword-key)))
  (printf "  int64 算術           %q" (* (r2 :int64) 2))
  (printf "  存回來的函式         (f 21) => %q" ((r2 :closure) 21))
  (printf "  同一份丟給 json/encode 會怎樣：%q"
          (first (protect (json/encode 進階))))

  (h "什麼時候用哪個")
  (print "  設定檔 / 要給別的程式看 / 要進 git → JSON")
  (print "  快取 / 中繼檔 / 要保留 Janet 型別  → marshal")
  (print "  ★ marshal 出來的東西別當長期儲存格式：換 Janet 版本可能讀不回來")

  (h "收尾")
  (each f [json-path marshal-path p2] (os/rm f))
  (os/rmdir tmp)
  (print "  暫存檔已清掉\n"))
