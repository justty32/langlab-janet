# 投遞協定（aos spec 07：S-07-33、S-07-35、S-07-38、S-07-53）。
# 四步：寫 <id>.json.temp → 刷 → 改名成 <id>.json → 刷目錄。
# ⚠ Janet 沒有 fsync，兩個「刷」只做得到 file/flush（見 fsx.janet 檔頭）。

(import spork/json)
(import spork/path)
(import ./fsx)
(import ./land :as L)

(def kinds ["inst" "mail" "llm"])

(defn delivery
  ``組一個投遞物。共同欄位照 S-07-38：format_version／id／kind／from／at。
  extra 是依 kind 的其餘欄位（inst 帶 :inst，mail 帶 :subject/:body，llm 帶 :prompt/:result）。``
  [kind from &opt extra]
  (default extra {})
  (unless (index-of (string kind) kinds)
    (errorf "投遞物的 kind 是 %q，只認得 %s" kind (string/join kinds "／")))
  (merge @{} extra
         {:format_version 1
          :id (or (extra :id) (fsx/new-id))
          :kind (string kind)
          :from (L/root-of from)
          :at (fsx/now-iso)}))

(defn deliver!
  ``把一個投遞物放進某塊地的收件匣。回傳投遞檔的路徑。

  S-07-53：投遞禁止建目錄——目標不是一塊地就當投遞失敗，不幫它 mkdir。``
  [l obj]
  (def target (L/land l))          # 不是地就在這裡報錯（含指路）
  (def id (or (obj :id) (obj "id")))
  (unless (fsx/hex-id? id)
    (errorf "投遞物的 id 必須是 32 個小寫 hex（S-07-35），拿到的是 %q。下一步：用 (aos/new-id)" id))
  (def inbox (target :inbox))
  (def final (path/join inbox (string id ".json")))
  (when (fsx/exists? final)
    (errorf "重複投遞：id %s 已經在 %s 的收件匣裡（S-07-39）" id (target :root)))
  (def cap (or ((fsx/read-json (target :config) {}) :inbox_max) 1000))
  (def n (length (filter |(string/has-suffix? ".json" $) (os/dir inbox))))
  (when (>= n cap)
    (errorf "收件匣背壓：%s 已經有 %d 封，上限 %d（S-07-44）。下一步：先讓它走幾格把信收掉"
            (target :root) n cap))
  # 寫 .json.temp → 改名（原型 inbox.deliver 也是這個順序，兩邊互通）
  (def temp (string final ".temp"))
  (fsx/atomic-write temp (string (json/encode obj "  " "\n") "\n"))
  (os/rename temp final)
  final)

(defn mail!
  "投一封信（kind:mail）：只被搬到 .aos/mail/，不會被執行（S-07-45）。"
  [l subject body &opt from]
  (deliver! l (delivery :mail (or from (L/root-of (L/workspace)))
                        {:subject (string subject) :body (string body)})))
