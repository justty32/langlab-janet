#!/usr/bin/env janet
# 程式跑完之後，掉進一個 REPL——而且你自己定義的東西在裡面直接可用。
# 拿來當「可互動的工具」很好用：載完資料、建好連線，剩下手動探索。
#
# 跑法：
#   janet snippets/repl-mode.janet              # 跑完進 REPL
#   janet snippets/repl-mode.janet --no-repl    # 只跑不進
#   echo '(狀態)' | janet snippets/repl-mode.janet   # 非互動也吃（管線餵指令）
#
# 三種做法，由簡到繁：
#   1. janet -r script.janet          最省事，不必改程式碼
#   2. (repl nil nil (curenv))        在程式裡任意一點掉進去，用當前 env
#   3. (repl nil nil 自己造的 env)    給它一張特製的 env（沙箱／限定 API）
#
# 重點：
#   * ★★ (repl) 不給 env 的話用的是一張**全新的 env**，你自己定義的東西
#     在裡面通通看不到（實測：(repl) 之後打 x 會說 unknown symbol）。
#     要看得到就明確傳 (curenv) 進去。
#   * (defn main …) 裡面用 def 定義的是「區域變數」，就算傳了 curenv 也看不到——
#     要讓 REPL 看得見，就定義在頂層，或自己 put 進 env
#   * ★ 預設的輸入來源是 getline，需要終端機。要讓管線／檔案也能餵，
#     自己給一個 chunks 函式（見下面的 make-chunks）

# ── 這些定義在頂層，所以 REPL 裡直接叫得到 ──────────────────────────
(def 啟動時間 (os/time))

(var 計數 0)

(def 資料 @{:users @[@{:name "Alice" :age 30} @{:name "Bob" :age 25}]
            :version "1.0"})

(defn 狀態
  "看目前狀態——在 REPL 裡打 (狀態) 就會叫到這個。"
  []
  @{:啟動時間 啟動時間
    :已經過   (- (os/time) 啟動時間)
    :計數     計數
    :人數     (length (資料 :users))})

(defn 加一 [] (++ 計數))

(defn 找人
  "示範一個「查詢」函式，REPL 裡最常做的就是這種事。"
  [name]
  (find |(= name ($ :name)) (資料 :users)))

# ── 做法 3 要用的：一張只放特定 API 的 env ───────────────────────────
(defn make-tool-env
  "造一張限定的 env：核心函式都有，但只額外露出我指定的那幾個。
  適合做「給別人用的互動介面」，不想把整個內部狀態攤開。"
  []
  (def e (make-env))                       # 繼承 root-env，所以 + map print 都在
  (put e '狀態  @{:value 狀態  :doc "看目前狀態"})
  (put e '找人  @{:value 找人  :doc "用名字查一筆，例：(找人 `Alice`)"})
  (put e '加一  @{:value 加一  :doc "計數 +1"})
  # 動態變數也可以先設好
  (put e :pretty-format "%.20P")
  e)

(defn make-chunks
  "REPL 的輸入來源。互動時用預設的 getline（有歷史紀錄與自動補全），
  被管線／檔案餵的時候改成逐行讀 stdin，這樣非互動也能跑。"
  []
  (if (os/isatty stdin)
    nil                                    # nil = 用預設的 getline
    (fn [buf _parser] (file/read stdin :line buf))))

(defn 說明 [env-desc]
  (print "\n╭─────────────────────────────────────────────")
  (printf "│ 進入 REPL（%s）" env-desc)
  (print "│ 試試：")
  (print "│   (狀態)            看目前狀態")
  (print "│   (找人 \"Alice\")    查一筆")
  (print "│   (加一) (加一) (狀態)")
  (print "│   (doc 找人)        看說明")
  (print "│   (os/exit) 或 Ctrl-D 離開")
  (print "╰─────────────────────────────────────────────\n"))

(defn main [& args]
  (def no-repl (some |(= $ "--no-repl") args))
  (def 沙箱   (some |(= $ "--sandbox") args))

  # ── 這裡是「程式本體」，正常做事 ──────────────────────────────
  (print "── 程式本體先跑 ──")
  (printf "  載入了 %d 筆資料，版本 %s" (length (資料 :users)) (資料 :version))
  (加一)
  (printf "  狀態：%q" (狀態))

  (when no-repl
    (print "\n（--no-repl，直接結束）")
    (os/exit 0))

  # ── 掉進 REPL ─────────────────────────────────────────────────
  (if 沙箱
    (do
      (說明 "沙箱 env——只看得到 狀態／找人／加一")
      # 做法 3：指定一張自己的 env
      (repl (make-chunks) nil (make-tool-env)))
    (do
      (說明 "當前 env——本檔頂層的東西全都在")
      # 做法 2：★ 一定要傳 (curenv)，不然 REPL 看不到上面那些定義
      (repl (make-chunks) nil (curenv)))))

# ── 附錄：其他進 REPL 的方式（都不用改程式碼）───────────────────────
#
# janet -r snippets/repl-mode.janet
#   跑完腳本後進 REPL。跟 (repl) 幾乎一樣，但不必在程式裡寫任何東西。
#
# janet -l ./snippets/repl-mode -r
#   先載入成模組再進 REPL。注意 -l 只是 require 進 module/cache、
#   ★ 不會幫你建綁定，所以 REPL 裡還是得自己 (import ./snippets/repl-mode)。
#
# janet -e '(import ./snippets/repl-mode :as m)' -r
#   這個才真的把綁定帶進 REPL：(m/狀態)
#
# 遠端版：spork/netrepl 可以讓「正在跑的行程」開一個 REPL 埠，
#   連進去改東西而不用重啟——做 server 時很好用。
