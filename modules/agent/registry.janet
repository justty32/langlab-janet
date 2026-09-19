# 工具箱（tool registry）—— 「一個工具長什麼樣」與「怎麼變成 llm-http 吃的形狀」只在這裡定義。
#
# 一個工具就是一張 table：
#   @{:name "calc" :description "…" :parameters {JSON schema} :handler (fn [args] …)}
# handler 收一張解好的參數 table（key 是 keyword），回字串；回別的東西會被 encode 成 JSON。
#
# 這一層不認識 endpoint、不打網路：純資料轉換 ＋ 一個 call-tool。
# ★ call-tool 的行為刻意跟 llm-http/tools.janet 的 invoke 一致：handler 丟例外時
#   回「工具執行失敗：…」字串給模型，不讓整條 loop 掛掉；沒這個工具也是回錯誤字串。

(import spork/json)
(import ../llm-http/tools :as lt)

(def name-peg
  "OpenAI 只收 [A-Za-z0-9_-] 的工具名；中文名字送過去多半直接 400。"
  (peg/compile ~(* (some (+ :w "_" "-")) -1)))

(defn make-tool
  ``組一個工具 table。parameters 是 JSON schema（:type "object" 那種），用 Janet 的 struct 直接寫。
  名字不合法、schema 不是表、handler 不是函式 —— 都當場丟中文錯誤，不等到模型呼叫才炸。``
  [name description parameters handler]
  (def n (string name))
  (unless (peg/match name-peg n)
    (error (string "工具名「" n "」只能用英數字、底線與連字號")))
  (unless (dictionary? parameters)
    (error (string "工具「" n "」的 parameters 必須是一份 JSON schema（table／struct）")))
  (unless (function? handler)
    (error (string "工具「" n "」的 handler 必須是函式")))
  @{:name n :description (string description) :parameters parameters :handler handler})

(defmacro deftool
  ``定義一個工具並綁到同名的變數：

    (deftool add "把兩個數字相加"
      {:type "object" :properties {:a {:type "number"} :b {:type "number"}} :required ["a" "b"]}
      [args]
      (+ (get args :a 0) (get args :b 0)))

  之後 add 就是一張工具 table，塞進 make-agent 的 :tools 陣列即可。``
  [sym description parameters params & body]
  ~(def ,sym (,make-tool ,(string sym) ,description ,parameters (fn ,params ,;body))))

(defn tool?
  "是不是一張合法的工具 table。"
  [x]
  (and (dictionary? x) (string? (get x :name)) (function? (get x :handler))))

(defn as-table
  ``把「工具的陣列」或「名字 → 工具的 table」統一成後者（回新的 table）。
  ⚠ 同名工具後面的蓋前面的。``
  [tools]
  (def out @{})
  (cond
    (indexed? tools)   (each t tools (put out (get t :name) t))
    (dictionary? tools) (eachp [_ t] tools (put out (get t :name) t))
    (error (string "tools 要是工具陣列或 table，收到 " (type tools))))
  (eachp [n t] out
    (unless (tool? t) (error (string "「" n "」不是工具 table（要用 make-tool／deftool 做）"))))
  out)

(defn make-registry
  "建一個 registry（名字 → 工具的 table），可以先塞幾個進去。"
  [& tools]
  (as-table tools))

(defn register-tool!
  "把一個工具放進 registry（同名覆蓋），回傳那個工具。"
  [registry tool]
  (unless (tool? tool) (error "register-tool! 只收 make-tool／deftool 做出來的工具"))
  (put registry (tool :name) tool)
  tool)

(defn tool-names
  "registry／陣列裡所有工具的名字（排序過）。"
  [tools]
  (sorted (keys (as-table tools))))

(defn tools->specs
  "轉成 llm-http 的 tool-spec 陣列（送給模型的宣告）。"
  [tools]
  (seq [n :in (tool-names tools) :let [t (get (as-table tools) n)]]
    (lt/tool-spec (t :name) (t :description) (t :parameters))))

(defn tools->handlers
  "轉成 llm-http/with-tools 吃的「名字 → 函式」表。"
  [tools]
  (def out @{})
  (eachp [n t] (as-table tools) (put out n (t :handler)))
  out)

(defn- stringify
  "工具的回傳值要以字串送回模型：字串原樣，其他東西 encode 成 JSON（跟 llm-http 一致）。"
  [v]
  (cond
    (string? v) v
    (buffer? v) (string v)
    (nil? v)    ""
    (string (json/encode v))))

(defn decode-args
  "把模型給的 :function :arguments（一段 JSON 字串）解成 table；解不開就給空 table。"
  [raw]
  (if (or (nil? raw) (empty? raw))
    @{}
    (let [[ok v] (protect (json/decode raw true))]
      (if (and ok (dictionary? v)) v @{}))))

(defn call-tool
  ``照名字執行一個工具，**一定回字串**：
    * 沒這個工具 → "錯誤：沒有名為 X 的工具"
    * handler 丟例外 → "工具執行失敗：…"（模型看得懂，通常會改參數重試）
  args 可以是 table，也可以直接給 JSON 字串（會先 decode）。``
  [tools name args]
  (def t (get (as-table tools) (string name)))
  (def a (if (bytes? args) (decode-args args) (or args @{})))
  (if (nil? t)
    (string "錯誤：沒有名為 " name " 的工具")
    (let [[ok v] (protect ((t :handler) a))]
      (if ok (stringify v) (string "工具執行失敗：" v)))))
