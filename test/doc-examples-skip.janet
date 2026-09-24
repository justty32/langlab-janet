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
    # ⑤ 用到**前一個**區塊 import 的東西（gen/、:prefix "" 的 misc），這個區塊自己沒 import；
    #    harness 每個區塊一個新 env，所以 dfs／column-combine／gen/map 全是 unknown symbol。
    (tabseq [k :in ["30-spork-並行與服務.md:81" "reference/spork/misc-順手工具.md:75"
                    "reference/spork/misc-順手工具b-陣列與資料表.md:85"]] k :靠前一區塊import)
    # ⑥ 要磁碟上真的有 /path/to/src.txt（示範用的假路徑），add-file 讀不到就整條走樣
    (tabseq [k :in ["reference/spork/壓縮與封存-zip.md:76" "reference/spork/壓縮與封存-zip.md:77"
                    "reference/spork/壓縮與封存-zip.md:78"]] k :要特定檔案)))

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
           "永遠跑不完"
           # ⚠ 下面這些以前靠「區塊裡的 import 沒生效」默默擋掉，import 修好後要明列：
           #   spork/sh 會開子行程、sh/rm 刪目錄；tasker 寫 ./tasks；zip/write-file 寫檔；rpc 開 TCP 埠。
           "spork/sh" "(sh/" "tasker/" "zip/write-file" "rpc/"
           # ⚠ 會讀 stdin 的互動示範（docs/41 的 make-getline）。區塊裡的 import 生效之後
           #   它真的會跑，jpm test 在終端機裡就卡著等鍵盤輸入。
           "make-getline" "(getline" "rawterm/getch" "file/read stdin"])

(defn 危險區塊? [src] (some |(string/find $ src) 危險))
