# agent：sandbox 路徑判斷 ＋ 檔案工具（read-file／list-dir／write-file／search-files）。
# 在暫存目錄裡造一個小工作區，跑完清掉。不打網路。

(import spork/path)
(import ../modules/agent/init :as ag)
(import ./util :as u)

(def work (string (or (os/getenv "TMPDIR") "/tmp") "/janet-agent-sandbox-" (os/getpid)))
(os/mkdir work)
(os/mkdir (path/join work "sub"))
(spit (path/join work "a.txt") "hello\nworld\n")
(spit (path/join work "sub" "b.txt") "world again\n")
(spit (path/join work "bin.dat") "abc\0def world")
# root 裡放一個指到外面的 symlink，看 resolve-existing 擋不擋得住
(os/symlink "/" (path/join work "escape"))

(def sb (ag/make-sandbox work))
(assert (= (os/realpath work) (sb :root)) "root 是 realpath 過的絕對路徑")
(assert (not (sb :write?)) "寫入預設關閉")
(assert (string/find "不存在" (u/err-of |(ag/make-sandbox (path/join work "沒這個")))))
(assert (string/find "不是資料夾" (u/err-of |(ag/make-sandbox (path/join work "a.txt")))))

# ── resolve-path：.. 與絕對路徑都擋 ─────────────────────────────────
(assert (= (path/join (sb :root) "a.txt") (ag/resolve-path sb "a.txt")))
(assert (= (path/join (sb :root) "a.txt") (ag/resolve-path sb "./sub/../a.txt")) "沒真的跳出去的 .. 可以")
(assert (= (sb :root) (ag/resolve-path sb ".")) "root 自己也算在裡面")
(assert (string/find "跳出了允許的根目錄" (u/err-of |(ag/resolve-path sb "../x"))) "..")
(assert (string/find "跳出了允許的根目錄" (u/err-of |(ag/resolve-path sb "sub/../../x"))) "繞一圈的 ..")
(assert (string/find "跳出了允許的根目錄" (u/err-of |(ag/resolve-path sb "/etc/passwd"))) "絕對路徑")
(assert (= (path/join (sb :root) "sub") (ag/resolve-path sb (path/join (sb :root) "sub")))
        "落在 root 底下的絕對路徑可以")
(assert (string/find "跳出了" (u/err-of |(ag/resolve-path sb (string (sb :root) "-evil/x"))))
        "只是前綴像 root 的路徑不算在裡面")
(assert (string/find "路徑是空的" (u/err-of |(ag/resolve-path sb ""))))

# resolve-existing：要存在，而且 symlink 解開後還要在裡面
(assert (string/find "找不到" (u/err-of |(ag/resolve-existing sb "沒這個.txt"))))
(assert (string/find "跳出了允許的根目錄" (u/err-of |(ag/resolve-existing sb "escape/etc/passwd")))
        "symlink 指到外面要擋")

# resolve-for-write：預設關閉；開了之後上層資料夾要存在
(assert (string/find "沒有開放寫入" (u/err-of |(ag/resolve-for-write sb "new.txt"))))
(def sbw (ag/make-sandbox work :write? true))
(assert (= (path/join (sbw :root) "new.txt") (ag/resolve-for-write sbw "new.txt")) "新檔可以（不用先存在）")
(assert (string/find "上層資料夾不存在" (u/err-of |(ag/resolve-for-write sbw "沒這層/x.txt"))))
(assert (string/find "跳出了" (u/err-of |(ag/resolve-for-write sbw "../x.txt"))))
(assert (string/find "跳出了" (u/err-of |(ag/resolve-for-write sbw "escape/tmp/x.txt"))) "經 symlink 寫到外面也擋")

# ── 檔案工具 ────────────────────────────────────────────────────────
(def ro (ag/fs-tools sb))
(assert (deep= @["list-dir" "read-file"] (ag/tool-names ro)) "只讀 sandbox 沒有 write-file")
(def rw (ag/fs-tools sbw))
(assert (deep= @["list-dir" "read-file" "write-file"] (ag/tool-names rw)) "開了 :write? 才有 write-file")

(assert (= "hello\nworld\n" (ag/call-tool ro "read-file" @{:path "a.txt"})))
(assert (string/has-prefix? "工具執行失敗：拒絕" (ag/call-tool ro "read-file" @{:path "../etc/passwd"}))
        "跳出去的讀取回錯誤字串給模型，不丟例外")
(assert (string/find "不是檔案" (ag/call-tool ro "read-file" @{:path "sub"})))
(def big-tool (ag/read-file-tool sb :max-bytes 5))
(assert (string/has-prefix? "hello\n…（已截斷" (ag/call-tool [big-tool] "read-file" @{:path "a.txt"})) "截斷")

(def listed (ag/call-tool ro "list-dir" @{}))
(assert (string/find "f a.txt (12 bytes)" listed) (string "list-dir 格式：" listed))
(assert (string/find "d sub/" listed))
(assert (= "f b.txt (12 bytes)" (ag/call-tool ro "list-dir" @{:path "sub"})))
(assert (string/find "不是資料夾" (ag/call-tool ro "list-dir" @{:path "a.txt"})))

(assert (= "錯誤：沒有名為 write-file 的工具" (ag/call-tool ro "write-file" @{:path "x" :content "1"})))
(assert (= "已寫入 sub/c.txt（3 bytes）" (ag/call-tool rw "write-file" @{:path "sub/c.txt" :content "new"})))
(assert (= "new" (string (slurp (path/join work "sub" "c.txt")))) "真的寫進去了")
(assert (string/has-prefix? "工具執行失敗：拒絕" (ag/call-tool rw "write-file" @{:path "/tmp/evil" :content "x"})))

# ── search-files：純文字、遞迴、跳過二進位、上限 ─────────────────────
(def hits (ag/search-files sb "world"))
(assert (deep= @["a.txt:2: world" "sub/b.txt:1: world again"] hits) (string/format "%q" hits))
(assert (deep= @["sub/b.txt:1: world again"] (ag/search-files sb "world" :dir "sub")) "限定子資料夾")
(assert (= 1 (length (ag/search-files sb "world" :max-hits 1))) "上限")
(assert (empty? (ag/search-files sb "abc")) "含 NUL 的二進位檔跳過")
(assert (empty? (ag/search-files sb "a.t")) "純文字比對，不是 regex（. 不是萬用字元）")
(def st (ag/search-files-tool sb :max-hits 1))
(assert (string/find "只列前 1 筆" (ag/call-tool [st] "search-files" @{:pattern "world"})))
(assert (= "（沒有找到）" (ag/call-tool [st] "search-files" @{:pattern "zzz"})))
(assert (string/has-prefix? "工具執行失敗：拒絕" (ag/call-tool [st] "search-files" @{:pattern "x" :path "../"})))

# ── default-tools 的組成 ────────────────────────────────────────────
(assert (deep= @["calc" "http-get" "list-dir" "now" "read-file" "search-files"]
                (ag/tool-names (ag/default-tools :root work))) "預設：只讀、沒 shell")
(assert (index-of "write-file" (ag/tool-names (ag/default-tools :root work :write? true))))
(assert (index-of "run-command" (ag/tool-names (ag/default-tools :root work :shell true))))
(assert (not (index-of "http-get" (ag/tool-names (ag/default-tools :root work :http? false)))))

# 清掉工作區
(os/rm (path/join work "escape"))
(each f ["sub/b.txt" "sub/c.txt" "sub" "a.txt" "bin.dat"] (os/rm (path/join work f)))
(os/rm work)
(print "agent sandbox／檔案工具測試通過 ✓")
