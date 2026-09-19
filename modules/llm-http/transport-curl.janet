# curl 傳輸 —— 用子行程呼叫 curl 收送 JSON，讓 https:// 也打得通。
#
# spork/http 底層是 net/connect，沒有 TLS；要直打 Anthropic／OpenAI／DeepSeek 這種
# https 端點，最省事的路是把 TLS 交給系統的 curl。這支只做「送一個 request、
# 把回應解成 Janet 資料」，不認識 messages／tools，跟 transport.janet 的 post-chat 同形狀。
#
# ★ 金鑰不能出現在命令列（`ps` 看得到整條 argv）。實測後的做法：
#   header 全部寫進一個暫存檔，命令列只有 `-H @那個檔`；body 從 stdin 餵（`--data-binary @-`）。
#   暫存檔用 (os/umask 8r077) 包住 spit 建立，所以建檔當下就是 0600，用完 defer 刪掉。
#   （curl 的 `-H @file` 是 7.55 起支援的；`--config` 也行，但 quote 規則跟 JSON 打架。）
#
# ⚠ 實測踩到的點：
#   * 不用 `--fail`：它會把非 2xx 的 body 吞掉，你就看不到伺服器說「model 不存在」
#     還是「金鑰錯」。改用 `-w '\n%{http_code}'` 把狀態碼接在 body 最後一行，
#     自己切開來判斷；stderr 才是 curl 自己的錯誤訊息（連不上、憑證錯…）。
#   * curl 不在 PATH 時 os/spawn 直接丟例外，訊息是英文的 "Could not spawn"；這裡先用
#     curl-available? 探一次，把它換成講得清楚的中文。

(import spork/json)

(def curl-command
  "呼叫的執行檔名；環境變數 LLM_HTTP_CURL 可以指到別的路徑。"
  (or (os/getenv "LLM_HTTP_CURL") "curl"))

(defn curl-available?
  "這台機器找不找得到 curl（跑一次 `curl --version`）。測試靠它決定要不要跳過。"
  []
  (def [ok p] (protect (os/spawn [curl-command "--version"] :p {:out :pipe :err :pipe})))
  (if ok
    (do (ev/read (p :out) :all) (ev/read (p :err) :all) (zero? (os/proc-wait p)))
    false))

(defn- header-lines
  "把 header 表變成 curl -H @file 吃的格式：一行一個「名字: 值」。"
  [headers]
  (string/join (seq [[k v] :pairs headers] (string k ": " v)) "\n"))

(defn- private-temp-file
  "在 TMPDIR 建一個只有自己讀得到（0600）的暫存檔，寫進 content，回路徑。"
  [content]
  (def dir (or (os/getenv "TMPDIR") "/tmp"))
  (def name (string/format "%s/llm-http-%s.hdr" dir
                           (string/join (map |(string/format "%02x" $) (os/cryptorand 8)) "")))
  # ★ umask 8r077 → 建出來的檔案就是 0600，沒有「先建再 chmod」的空窗
  (def old (os/umask 8r077))
  (defer (os/umask old)
    (spit name content))
  name)

(defn- describe-exit
  "把 curl 的 exit code 翻成一句中文（只列最常撞到的）。"
  [code stderr]
  (def msg (string/trim (string stderr)))
  (case code
    6  (string "解析不了主機名稱：" msg)
    7  (string "連不上（curl exit 7）：" msg)
    28 (string "逾時（curl --max-time）：" msg)
    35 (string "TLS 交握失敗：" msg)
    60 (string "TLS 憑證驗證失敗：" msg)
    (string "curl 失敗（exit " code "）：" msg)))

(defn- last-newline
  "最後一個 \\n 的位置；沒有就回 -1。"
  [s]
  (var i (dec (length s)))
  (while (and (>= i 0) (not= 10 (get s i))) (-- i))
  i)

(defn curl-run
  ``spawn 一個 curl：header 走暫存檔、body 走 stdin，命令列上沒有金鑰。

  f 收 proc，**要負責把 stdout 讀完**（讀全部或逐行都行）；回 [f 的結果 exit-code stderr]。
  extra 是額外的 argv（例如串流用的 "-N"）。暫存檔在 curl 結束後才刪——它是啟動時讀的，
  但刪早了在慢機器上有機會撞到。``
  [method url headers body timeout extra f]
  (def hdr-file (private-temp-file (header-lines headers)))
  (defer (protect (os/rm hdr-file))
    (def argv @[curl-command "-sS" "-X" method "-H" (string "@" hdr-file)
                "-w" "\n%{http_code}" ;(or extra [])])
    (when body    (array/push argv "--data-binary" "@-"))
    (when timeout (array/push argv "--max-time" (string timeout)))
    (array/push argv url)
    (def [ok p] (protect (os/spawn argv :p {:in :pipe :out :pipe :err :pipe})))
    (unless ok
      (error (string "叫不動 " curl-command "（不在 PATH 上？）：" p)))
    (when body (ev/write (p :in) body))
    (ev/close (p :in))
    # ★ 先把 stdout／stderr 讀完再 proc-wait，否則 pipe 塞滿時子行程會卡住
    (def v (f p))
    (def err (string (ev/read (p :err) :all)))
    (def code (os/proc-wait p))
    [v code err]))

(defn curl-request
  ``用 curl 送一個 request，回 @{:status 整數 :body 字串}。

  method  "POST"／"GET"
  url     完整網址（http 或 https 都行）
  headers 一張表；**不會**出現在命令列上（走 -H @暫存檔）
  body    字串或 nil；有給就從 stdin 餵給 curl
  timeout 秒數或 nil（對應 --max-time）

  連不上／TLS 失敗這類 curl 自己的錯誤丟中文例外；HTTP 非 2xx **不在這裡丟**，
  呼叫端看 :status 決定（跟 spork/http 的 http/request 對齊）。``
  [method url headers &opt body timeout]
  (def [out code err]
    (curl-run method url headers body timeout nil (fn [p] (string (ev/read (p :out) :all)))))
  (unless (zero? code)
    (error (string "連不上 " url "：" (describe-exit code err))))
  # -w 把狀態碼接在 body 最後一行（Janet 沒有 string/rfind，自己往回找最後一個換行）
  (def cut (last-newline out))
  @{:status (scan-number (string/slice out (inc cut)))
    :body   (string/slice out 0 (max 0 cut))})

(defn curl-json
  ``送 JSON、收 JSON：payload 會 json/encode，回應解成 key 是 keyword 的 Janet 資料。
  非 2xx、非 JSON 一律丟中文例外（訊息裡帶伺服器回的原文）。``
  [method url headers &opt payload timeout]
  (def res (curl-request method url headers
                         (when payload (string (json/encode payload))) timeout))
  (def status (res :status))
  (def text (res :body))
  (unless (and status (<= 200 status 299))
    (error (string/format "HTTP %q（%s）：%s" status url (string/trim text))))
  (def [ok v] (protect (json/decode text true)))
  (unless ok
    (error (string "回應不是合法 JSON：" (string/trim text))))
  v)
