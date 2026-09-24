# doc-examples 的「不跑／不比對」名單——抽出來只是為了守檔案大小慣例（≤150 行）。
#
# ⚠ jpm test 會把 test/ 底下每一支 .janet 都當測試跑，所以這支被單獨執行時什麼都不做
#   （只有定義），這是刻意的——不要在這裡放會印東西的程式碼。名單怎麼加減見 doc-examples.janet。

# 刻意不比對的案例，按原因分組。名單只准縮短，不准為了讓測試變綠而隨便加長。
(def 不比對
  (merge
    # ① %j 會把中文逃逸成 \xE4\xBD\xA0…，文件寫給人看的那個才是對的
    (tabseq [k :in ["02-資料結構.md:92" "03-json.md:57" "32-條件與模式比對.md:73"
                    "32-條件與模式比對.md:74" "40-內建動態變數.md:45"
                    "28b-spork-misc-文字與流程.md:65"]] k :逃逸中文)
    # ② 文件寫的是散文描述或所有可能值，不是單一個值
    (tabseq [k :in ["16-marshal-與自省.md:51" "16-marshal-與自省.md:52"
                    "19b-檔案系統與路徑.md:32" "19b-檔案系統與路徑.md:51"
                    "24-時間與日期.md:89" "03-json.md:48"]] k :散文)
    # ③ 結果本來就會變（時間、亂數、當下的檔案）
    (tabseq [k :in ["24-時間與日期.md:15" "26-隨機數.md:30" "26-隨機數.md:99"
                    "29-spork-資料與文字.md:123" "29-spork-資料與文字.md:124"
                    "19b-檔案系統與路徑.md:12" "19b-檔案系統與路徑.md:13"]] k :會變)
    # ④ 預期值本身含兩個空白，被說明文字的切法切爛（見「期望值」的註解）
    (tabseq [k :in ["02-資料結構.md:36" "reference/spork/資料格式與驗證.md:18"
                    "reference/peg-全表.md:58"]] k :切不乾淨)
    # ⑤ 前一行 setdyn 的值下一行讀不到：求值包在 (with-dyns …) 裡，而 with-dyns
    #    是「開一個新 fiber 跑 body」，dyn 又是 fiber-local，所以效果隨那個 form 結束。
    #    文件寫的 true 是在 REPL 裡實測的，對；驗不了的是這個 harness。
    (tabseq [k :in ["12c-dyn.md:22" "12c-dyn.md:78"]] k :dyn跨不過fiber)
    # ⑥ (protect (eval …))：eval 在 protect 開的新 fiber 裡跑，看不到 harness 給區塊的 env，
    #    於是區塊前面 import 的 infix/$$ 變成 unknown symbol。用 janet 直接跑檔實測文件是對的。
    (tabseq [k :in ["reference/spork/infix-中綴算式.md:110"
                    "reference/spork/infix-中綴算式.md:111"]] k :eval看不到區塊env)))

# 這些字樣一出現就整個區塊不跑：會動檔案系統、開子行程、或需要外部服務。
(def 危險 ["xprint" "os/execute" "os/spawn" "os/shell" "os/rm" "os/rmdir" "os/mkdir" "os/cd"
           "spit" "file/open" "file/temp" "net/" "http/" "sh/$" "os/exit" "os/sleep"
           # spork/test 的 end-suite 失敗時會 os/exit 1，名單只擋得到字面的 os/exit
           "end-suite"
           # ⚠ ev/ 一定要排除：開了 ev/thread 或 ev/go 的區塊會讓**整個行程結束不了**
           #   （Janet 會等那些任務），症狀是測試跑完卻不退出，很難聯想。
           "ev/"
           # ⚠ 文件裡**故意**示範跑不完的反例（docs/35b 那個 prewalk 無限遞迴）。
           #   自從整個區塊共用一個 env（見「在env求值」），它真的會跑起來並吃光記憶體，
           #   所以認這句註解當標記：要示範無窮迴圈就在那行寫「永遠跑不完」。
           "永遠跑不完"])

(defn 危險區塊? [src] (some |(string/find $ src) 危險))
