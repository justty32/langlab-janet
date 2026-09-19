# agent —— 站在 llm-http 上面的 agent 層（門面）。
#
#   llm-http  客戶端：打 OpenAI 相容端點、tool-spec、圖像輸入
#   agent     這一層：工具箱（含預設安全的內建工具）＋ 記憶／截斷 ＋ 迴圈 ＋ trace ＋ CLI
#
# ── 這支檔案只做 re-export ──────────────────────────────────────────
#   registry.janet      工具長什麼樣：make-tool／deftool／register-tool!／tools->specs／call-tool
#   sandbox.janet       路徑可不可以碰：make-sandbox／resolve-path／resolve-for-write
#   tools-fs.janet      read-file／list-dir／write-file（走 sandbox）
#   tools-search.janet  search-files（grep 式，走 sandbox）
#   tools-shell.janet   run-command（預設沒有；白名單／逾時／截斷）
#   tools-http.janet    http-get（只有 http://）
#   tools-misc.janet    now／calc（PEG 解算式，不 eval）
#   presets.janet       default-tools：一次組出預設安全的整組
#   memory.janet        記憶：make-memory／append!／trim!（整輪丟，不拆散 tool_calls）
#   memory-io.janet     save!／load（JSON）
#   trace.janet         事件 → 一行字：stderr-tracer／file-tracer／collect-tracer
#   agent.janet         make-agent／run
#   cli.janet           CLI（main.janet 只是進入點）
#
# 用法：(import ../modules/agent/init :as ag)
#   (def a (ag/make-agent {:endpoint "local" :tools (ag/default-tools :root ".")}))
#   (print ((ag/run a "這個資料夾有什麼？") :text))
#
# ★ import 的副作用跟 llm-http 一樣：會自動探測一次 endpoint 設定檔（沒有是正常的）。

(import ./registry     :prefix "" :export true)
(import ./sandbox      :prefix "" :export true)
(import ./tools-fs     :prefix "" :export true)
(import ./tools-search :prefix "" :export true)
(import ./tools-shell  :prefix "" :export true)
(import ./tools-http   :prefix "" :export true)
(import ./tools-misc   :prefix "" :export true)
(import ./presets      :prefix "" :export true)
(import ./memory       :prefix "" :export true)
(import ./memory-io    :prefix "" :export true)
(import ./trace        :prefix "" :export true)
(import ./agent        :prefix "" :export true)
