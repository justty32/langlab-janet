#!/usr/bin/env janet
# aos：資料夾當函式、檔案當指令 —— 一支從頭跑到尾的示範。
# 跑法：janet examples/aos-call.janet
#
# 跑起來會看到四段：建一塊地 → 同步呼叫它拿到結果 → 用 (aos/fn) 當函式再叫一次 →
# 把 /bin/sh 當一筆指令跑、把 stdout 與結束碼讀回來。全部在暫存目錄，不碰你的 ~。

(import ../modules/aos :as aos)

(defn h [s] (printf "\n── %s" s))

(defn main [&]
  (unless (aos/exists? (aos/proto-path))
    (printf "找不到 aos 原型 %s。下一步：設 AOS_PROTO 指到那支 aos.py" (aos/proto-path))
    (os/exit 0))

  # ★ 一律切一個暫存的家與暫存區，不要用真正的 ~
  (def sb (string (or (os/getenv "TMPDIR") "/tmp") "/aos-janet-demo-" (aos/new-id)))
  (os/setenv "AOS_HOME" (string sb "/home"))
  (os/setenv "AOS_JANET_WS" (string sb "/ws"))
  (aos/ensure-dir (string sb "/home"))

  (h "① 建一塊地：一個有 .aos/ 的資料夾就是一支程式")
  (def greeter
    (aos/init-land!
      (string sb "/greeter")
      {:source
       {:format_version 1 :name "main"
        :steps [{:name "say" :kind "inst"
                 :inst {:argv ["python3" "-c"
                               (string "import os,pathlib\n"
                                       "p=pathlib.Path(os.environ['AOS_RESULT'])\n"
                                       "p.parent.mkdir(parents=True,exist_ok=True)\n"
                                       "p.write_text('嗨 '+os.environ.get('AOS_ARG_WHO','?')+'！')\n")]}
                 :then "end"}]}}))
  (printf "  地：%s" (greeter :root))
  (printf "  它的程式：%s" (string (greeter :root) "/main.aos.json"))

  (h "② 同步呼叫：args 變成子地的 AOS_ARG_*，結果落在父指定的落點")
  # ⚠ 用 %s 不用 %q：%q 會把中文逃逸成 \xE5… （janet-lab 已知的坑）
  (printf "  (aos/call greeter {:who \"世界\"}) => %s" (aos/call greeter {:who "世界"}))
  (printf "  呼叫記錄寫在呼叫方那塊地：%s" ((aos/workspace) :calls))

  (h "③ (aos/fn 地)：資料夾當函式")
  (def greet (aos/fn greeter))
  (printf "  (greet {:who \"Janet\"}) => %s" (greet {:who "Janet"}))
  (printf "  (greet {:who \"aos\"})   => %s" (greet {:who "aos"}))

  (h "④ 檔案當指令：一筆指令＝一次 POSIX 呼叫")
  (def r (aos/exec-file "/bin/sh" "-c" "echo 我是一筆指令; echo 這行去 stderr >&2; exit 3"))
  (printf "  結束碼 => %q（傳輸層，不是「做成沒做成」）" (r :code))
  (prin "  stdout => ") (prin (r :out))
  (prin "  stderr => ") (prin (r :err))
  (printf "  執行結果檔 => %s" (r :result))

  (h "收尾")
  (printf "  暫存目錄留著給你看：%s" sb)
  (print "  要脫節呼叫（子地自己有鐘）就先 (aos/daemon :start)，再 (aos/call-async …) → (aos/await h)\n"))
