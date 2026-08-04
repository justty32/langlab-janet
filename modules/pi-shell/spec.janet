# agent 設定的**驗證與正規化** —— 純函式，不碰 registry、不 spawn 任何東西。
#
# ── 一份 agent 設定認得的欄位 ───────────────────────────────────────
#   :cmd           執行檔名，走 PATH 找                         ← **必填**
#   :prompt-flag   非互動旗標，預設 "-p"；給 false／nil 表示這支不用墊
#   :model-flag    指定 model 的旗標（"--model"）；沒有就表示這支不吃 model
#   :default-model 沒指定 model 時要不要墊一個；nil＝讓 CLI 自己用預設
#   :note          一句話說明
#
# ⚠ 本模組是**薄透傳**：設定只描述「怎麼起這支 CLI」，
#   刻意**不**放任何限制旗標（--no-tools／--disallowedTools）進來——
#   pi 與 claude 預設都帶 bash/edit/write，會真的動你的檔案，
#   要不要縮限是呼叫端每次自己的決定。

(def spec-keys
  "一份 agent 設定認得的欄位；拼錯會在註冊時被擋下來。"
  [:cmd :prompt-flag :model-flag :default-model :note :name])

(defn- fail
  [fmt & args]
  (error (string/format fmt ;args)))

(defn normalize-spec
  ``驗證一份 agent 設定並補上預設，回一份**全新的** table；有問題就丟中文錯誤。
  label 只是錯誤訊息裡的稱呼。``
  [spec &opt label]
  (default label "（未命名）")
  (unless (dictionary? spec)
    (fail "agent「%s」的設定必須是一張 table 或 struct，收到的是 %s" label (type spec)))

  (def unknown (filter |(not (index-of $ spec-keys)) (keys spec)))
  (unless (empty? unknown)
    (fail "agent「%s」的設定有不認得的欄位：%s\n可用欄位：%s"
          label
          (string/join (map |(string/format "%q" $) (sorted unknown)) "、")
          (string/join (map |(string/format "%q" $) spec-keys) " ")))

  (def cmd (get spec :cmd))
  (cond
    (nil? cmd)
    (fail "這份 agent 設定缺 :cmd —— agent「%s」必須指明執行檔名，例如 {:cmd \"my-agent\"}" label)
    (not (bytes? cmd))
    (fail "agent「%s」的 :cmd 必須是字串，收到 %s" label (type cmd)))

  (each k [:model-flag :default-model :note]
    (when-let [v (get spec k)]
      (unless (bytes? v)
        (fail "agent「%s」的 %q 必須是字串，收到 %s" label k (type v)))))

  # :prompt-flag 特別處理：沒給＝用預設的 "-p"，給 false／nil 字面 = 不墊任何旗標
  (def pf (if (has-key? spec :prompt-flag) (get spec :prompt-flag) "-p"))
  (unless (or (not pf) (bytes? pf))
    (fail "agent「%s」的 :prompt-flag 必須是字串或 false，收到 %s" label (type pf)))

  (def out @{:cmd (string cmd) :prompt-flag (if pf (string pf) nil)})
  (each k [:model-flag :default-model :note]
    (when-let [v (get spec k)] (put out k (string v))))
  out)
