# 配合 docs/39-跟作業系統打交道.md
#
#   janet examples/os-tour.janet
#   janet examples/os-tour.janet | cat      ← 用管線再跑一次，看 isatty 變 false
#
# 檔案操作都在系統暫存目錄裡做，跑完自己收乾淨。

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 秀 [說明 結果] (printf "  %-30s => %j" 說明 結果))

(節 "我現在在什麼機器上")
(秀 "(os/which)" (os/which))
(秀 "(os/arch)" (os/arch))
(秀 "(os/compiler)" (os/compiler))
(秀 "(os/cpu-count)" (os/cpu-count))
(printf "  → 跨平台分歧點：換行符號用 %j"
        (if (= :windows (os/which)) "\r\n" "\n"))

(節 "⚠ os/shell 回的不是 exit code，是 exit code × 256")
(if (= :windows (os/which))
  (print "  （這段是 POSIX 的 wait status 編碼，Windows 上不一樣，跳過）")
  (do
    (printf "  %-10s %-22s %s" "子行程" "os/shell" "os/execute")
    (each c [0 1 3 7]
      (printf "  exit %-5d %-22j %j"
              c
              (os/shell (string "exit " c))
              (os/execute ["sh" "-c" (string "exit " c)] :p)))
    (print "  os/shell 回的是 C system() 的原始 wait status，docstring 一個字都沒提")
    (print "  所以 (= 1 (os/shell \"exit 1\")) 永遠是 false")
    (print "  → 要判斷成敗就用 os/execute，它回乾淨的 exit code")))

(節 "os/isatty：輸出接到人，還是接到管線")
(秀 "(os/isatty stdout)" (os/isatty stdout))
(秀 "(os/isatty stderr)" (os/isatty stderr))
(def 上色? (os/isatty stdout))
(defn 紅 [s] (if 上色? (string "\e[31m" s "\e[0m") s))
(printf "  這行在終端機是紅的，接管線就是純文字：%s" (紅 "紅色"))
(print "  把這支檔用 | cat 再跑一次，上面兩個會變成 false")
(print "  ⚠ stdout 與 stderr 要分開問——常見 stdout 被導走、stderr 還在終端機上")

(節 "⚠ Janet 沒有八進位字面值")
(秀 "8r644  ← 正確寫法" 8r644)
(秀 "0644   ← 這是十進位的 644！" 0644)
(秀 "16rFF" 16rFF)
(秀 "2r1010" 2r1010)
(print "  0o644 連 parse 都過不了；0644 不報錯但意思完全不同——寫權限一定加 8r")

(節 "權限：三個函式互相翻譯")
(秀 "(os/perm-string 8r644)" (os/perm-string 8r644))
(秀 "(os/perm-int \"rw-r--r--\")" (os/perm-int "rw-r--r--"))
(printf "  %-30s => 8r%s" "  同一個值的八進位寫法" (string/format "%o" (os/perm-int "rw-r--r--")))

(節 "檔案操作補完（在暫存目錄裡做，跑完收乾淨）")
(def 工作區 (string (os/getenv "TMPDIR" "/tmp") "/janet-os-tour"))
(os/mkdir 工作區)
(def 檔 (string 工作區 "/a.txt"))
(spit 檔 "內容")

(秀 "os/realpath 有解出絕對路徑嗎" (string/has-suffix? "janet-os-tour/a.txt" (os/realpath 檔)))
(os/rename 檔 (string 工作區 "/b.txt"))
(秀 "os/rename 之後目錄裡有什麼" (os/dir 工作區))
(os/touch (string 工作區 "/b.txt"))
(秀 "os/touch 之後 mtime 的型別" (type ((os/stat (string 工作區 "/b.txt")) :modified)))

(printf "  %-30s => %s" "os/rmdir 對非空目錄"
        (try (do (os/rmdir 工作區) "刪掉了") ([e] (string "報錯：" e))))
(printf "  %-30s => %s" "os/touch 對不存在的檔"
        (try (do (os/touch (string 工作區 "/沒這個/x")) "建了") ([e] (string "報錯：" e))))
(printf "  %-30s => %s" "os/realpath 對不存在的路徑"
        (try (os/realpath (string 工作區 "/沒這個")) ([e] (string "報錯：" e))))

# 收乾淨
(os/rm (string 工作區 "/b.txt"))
(os/rmdir 工作區)
(秀 "收乾淨了嗎（nil = 目錄不在了）" (os/stat 工作區 :mode))

(節 "只有 POSIX 有的")
(print "  os/posix-fork / os/posix-exec / os/posix-chroot 在 Windows 上根本不存在")
(print "  用之前先問 (os/which)")

(print "\n✓ os-tour 跑完")
