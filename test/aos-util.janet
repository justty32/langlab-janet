# aos 測試的共用工具。⚠ jpm test 會把 test/ 每支 .janet 都跑一遍，所以這支只有定義。
#
# 三件事都在這裡做掉：找得到原型才跑（找不到就整支跳過）、切一個暫存的家與暫存區、
# 造一塊會把 $AOS_ARG_* 寫進 $AOS_RESULT 的小地。

(import ../modules/aos :as aos)

(defn proto-ready?
  "找不到 proto/aos.py 或沒有 python3 就跳過——這些測試要那支原型才跑得起來。"
  []
  (and (aos/exists? (aos/proto-path))
       (= 0 ((aos/aos-run ["--help"]) :code))))

(defn sandbox
  ``切一個乾淨的暫存沙盒：$AOS_HOME 與 lib 暫存區都指到 tmp，不碰使用者的 ~。
  回傳沙盒根目錄。``
  [name]
  (def root (string (or (os/getenv "TMPDIR") "/tmp") "/aos-janet-test/" name "-" (aos/new-id)))
  (aos/ensure-dir root)
  (os/setenv "AOS_HOME" (string root "/home"))
  (os/setenv "AOS_JANET_WS" (string root "/ws"))
  (aos/reset-workspace!)
  (aos/ensure-dir (string root "/home"))
  root)

(def echo-arg-source
  # 一塊地＝一支程式：把 AOS_ARG_WHO 寫進父指定的結果落點 $AOS_RESULT。
  {:format_version 1 :name "main"
   :steps [{:name "say" :kind "inst"
            :inst {:argv ["python3" "-c"
                          (string "import os,pathlib\n"
                                  "p=pathlib.Path(os.environ['AOS_RESULT'])\n"
                                  "p.parent.mkdir(parents=True,exist_ok=True)\n"
                                  "p.write_text('hi '+os.environ.get('AOS_ARG_WHO','?'))\n")]}
            :then "end"}]})

(def fail-source
  # 這塊地跑完不寫結果落點，也不寫狀態檔 → 父照 S-07-77 判 no_result。
  {:format_version 1 :name "main"
   :steps [{:name "nothing" :kind "inst" :inst {:argv ["/bin/true"]} :then "end"}]})

(def status-source
  # 這塊地自己把壞消息寫進 <落點>.status.json，父照三態讀成「壞了」。
  {:format_version 1 :name "main"
   :steps [{:name "boom" :kind "inst"
            :inst {:argv ["python3" "-c"
                          (string "import os,json,pathlib\n"
                                  "p=pathlib.Path(os.environ['AOS_RESULT']+'.status.json')\n"
                                  "p.parent.mkdir(parents=True,exist_ok=True)\n"
                                  "p.write_text(json.dumps({'format_version':1,'state':'failed',"
                                  "'reason':'boom','message':'測試用的壞消息','at':'2026-09-05T00:00:00.000Z'}))\n")]}
            :then "end"}]})
