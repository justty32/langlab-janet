#!/usr/bin/env janet
# 檢查一個 symbol（或 keyword / 字串）是不是以 "/" 或 "." 開頭。
# 跑法：janet snippets/symbol-prefix.janet
#
# 重點：
#   * symbol / keyword / string / buffer 都是 bytes，可以取第 n 個位元組
#   * ★ 但要用 (in x 0)，不能用 (x 0)——keyword/symbol 放在呼叫位置是「方法呼叫」
#   * 取出來是「數字」不是字元；Janet 沒有 char 型別，用 (chr "/") 拿字面值
#   * 所以比對有三種寫法，挑一種順手的：字串前綴 / 位元組比較 / PEG
#   * 跨型別 = 永遠 false，要嘛先 (string x) 統一，要嘛用吃 bytes 的函式

(defn starts-with-string?
  "寫法一：轉成字串用 string/has-prefix?（最好讀，也最常用）。
  string/has-prefix? 本身吃任何 bytes，其實連轉都不用轉。"
  [x]
  (or (string/has-prefix? "/" x)
      (string/has-prefix? "." x)))

(defn starts-with-byte?
  "寫法二：直接比第 0 個位元組。零配置、最快，但要記得那是數字。
  (chr \"/\") 在編譯期就算成 47，所以沒有執行期成本。"
  [x]
  (and (pos? (length x))
       (or (= (in x 0) (chr "/"))       # ★ (x 0) 不行，見檔頭說明
           (= (in x 0) (chr ".")))))

(def prefix-peg
  "寫法三：PEG。要判斷的規則一複雜（例如 ./ 、 ../ 、 /abs 分開處理）就換這個。"
  (peg/compile ~(+ (* "/" (constant :絕對路徑))
                   (* ".." (constant :上層相對))
                   (* "." (constant :相對路徑))
                   (constant :普通名字))))

(defn classify [x]
  (first (peg/match prefix-peg x)))

(defn main [&]
  (def 樣本 ['/usr/bin  './local  '../up  'plain  :/kw-abs  ".kw-dot"  "/字串"  ""])
  (printf "%-14s %-8s %-10s %-10s %s" "輸入" "型別" "has-prefix?" "byte 比較" "PEG 分類")
  (each x 樣本
    (printf "%-14q %-8q %-10q %-10q %q"
            x (type x)
            (starts-with-string? x)
            (starts-with-byte? x)
            (classify x)))

  (print "\n── 兩個容易踩的地方 ──")
  (printf "  (in '/abc 0)  => %q   ← 是數字，不是字元" (in '/abc 0))
  (printf "  ('/abc 0)     => %q   ← ✗ symbol 在呼叫位置＝方法呼叫，會炸"
          (protect ('/abc 0)))
  (printf "  (chr \"/\")     => %q   ← 字面字元，編譯期就算好" (chr "/"))
  (printf "  (string/from-bytes (in '/abc 0)) => %q" (string/from-bytes (in '/abc 0)))
  (printf "  (= \"/abc\" '/abc) => %q  ★ 跨型別永遠 false" (= "/abc" '/abc))
  (printf "  (= \"/abc\" (string '/abc)) => %q" (= "/abc" (string '/abc)))

  (print "\n── 實用版：拿來分辨 import 路徑 ──")
  (each m ['./sibling '../parent 'spork/json '/abs/path]
    (printf "  %-16q => %s" m
            (case (classify m)
              :絕對路徑 "檔案系統絕對路徑"
              :上層相對 "相對上層目錄"
              :相對路徑 "相對目前檔案"
              "系統模組（走 module/paths）"))))
