# 「一塊地」＝一個裡面有 .aos/ 的資料夾（aos spec 01 名詞表）。
# 這支只管：認一塊地、算出 .aos/ 底下那些路徑、必要時自己建一塊地。
# 建地是純 Janet 寫檔（照 proto 的 layout.init），不用 shell 出去。

(import spork/path)
(import ./fsx)

(defn land?
  "是不是本模組做出來的 land 物件。"
  [x]
  (and (table? x) (= :aos/land (get x :kind))))

(defn is-land?
  "這個路徑是不是一塊地：看 .aos/layout.json 在不在。"
  [p]
  (fsx/exists? (path/join (path/abspath p) ".aos" "layout.json")))

(defn land
  ``認一塊地，回一個 table。沒有 `.aos/` 就報清楚的錯（含下一步該做什麼）。

  (aos/land "sub/")            # 相對 cwd
  (aos/land "/home/u/work")``
  [p]
  (if (land? p) (break p))
  (def raw (path/abspath (string p)))
  (unless (= :directory (os/stat raw :mode))
    (errorf "%s 不是資料夾（也可能根本不存在）。下一步：先建它，再 (aos/init-land! \"%s\")" raw raw))
  (def root (os/realpath raw))
  (unless (is-land? root)
    (errorf (string "%s 不是一塊地：少了 %s/.aos/layout.json。\n"
                    "下一步：(aos/init-land! \"%s\")，或在 shell 跑 "
                    "`python3 <aos>/proto/aos.py init %s`")
            root root root root))
  @{:kind :aos/land
    :root root
    :aos (path/join root ".aos")
    :calls (path/join root ".aos" "calls")
    :inbox (path/join root ".aos" "inbox")
    :program (path/join root ".aos" "program")
    :series (path/join root ".aos" "series.json")
    :config (path/join root ".aos" "config.json")
    :ticks (path/join root ".aos" "ticks")})

(defn root-of [x]
  (if (land? x) (x :root) (or (os/realpath (string x)) (path/abspath (string x)))))

(defn resolve-in
  "路徑欄的規矩（spec S-07-54）：相對路徑以這塊地的根為原點，絕對路徑原樣。"
  [l p]
  (path/abspath (if (path/abspath? p) p (path/join (root-of l) p))))

(def- noop-source
  # 一塊地沒有 main.aos.json 就連 exec 都跑不起來（loader 要求 steps 非空），
  # 所以純收件匣用的地要塞一顆什麼都不做的步。詳見 janet-binding-findings 第 3 條。
  {:format_version 1 :name "main"
   :steps [{:name "noop" :kind "inst" :inst {:argv ["/bin/true"]} :then "end"}]})

(defn init-land!
  ``建一塊地：寫 .aos/layout.json、.aos/config.json 與那幾個空目錄。
  已經是一塊地就原樣回傳（不覆蓋）。
  opts：:source 一份原稿（table），:noop true 塞一份什麼都不做的原稿。``
  [p &opt opts]
  (default opts {})
  (def root (path/abspath (string p)))
  (fsx/ensure-dir root)
  (def a (path/join root ".aos"))
  (unless (is-land? root)
    (fsx/ensure-dir a)
    (fsx/write-json (path/join a "layout.json") {:format_version 1 :layout_version 1})
    (fsx/write-json (path/join a "config.json")
                    {:format_version 1 :path [] :max_parallel 4
                     :inst_timeout_ms 60000 :inbox_max 1000}))
  (each d ["inbox" "inbox/rejected" "control" "mail" "program" "calls" "tools"]
    (fsx/ensure-dir (path/join a d)))
  (def src (or (opts :source) (if (opts :noop) noop-source)))
  (when (and src (not (fsx/exists? (path/join root "main.aos.json"))))
    (fsx/write-json (path/join root "main.aos.json") src))
  (land root))

(var- ws nil)

(defn workspace
  ``lib 自己的暫存區，同時當「呼叫方那塊地」——呼叫記錄與預設結果落點都放這裡。

  ⚠ spec 假設呼叫方一定是一塊地（呼叫記錄寫在父的 .aos/calls/、落點以父地為原點）。
    Janet 這支行程不是地，所以只好合成一塊：AOS_JANET_WS，預設 $TMPDIR/aos-janet。``
  []
  (unless ws
    (def p (or (os/getenv "AOS_JANET_WS")
               (path/join (or (os/getenv "TMPDIR") "/tmp") "aos-janet")))
    (set ws (init-land! p {:noop true}))
    (fsx/ensure-dir (path/join (ws :root) "out")))
  ws)

(defn reset-workspace! "測試用：忘掉快取的暫存區。" [] (set ws nil))
