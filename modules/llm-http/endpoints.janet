# endpoint 這一整塊的**門面** —— 相容入口，也是「自動載入使用者設定檔」的觸發點。
#
# 原本這支檔案什麼都自己做；加了 registry ＋ 設定檔之後拆成六支，各管一件事：
#
#   defaults.janet  預設位址／金鑰、chat-url 怎麼組（LITELLM_BASE／LITELLM_API_KEY）
#   builtin.janet   內建四筆 endpoint 的**純資料**（local／deepseek／claude／openrouter）
#   spec.janet      一份設定合不合法：normalize-spec（純函式驗證）
#   registry.janet  表裡有誰：define-endpoint／reset-endpoints!／查來源
#   resolve.janet   組成可以打的 cfg：endpoint／env-ready?
#   config.janet    **設定檔 IO**：load-endpoints!／autoload-endpoints!（只 parse 不 eval）
#
# 舊寫法 (import ./endpoints :as ep) 之後照舊：ep/specs、ep/endpoint、ep/endpoint-names、
# ep/env-ready?、ep/base-url、ep/chat-url、ep/proxy-key 全部還在。
#
# ★ import 這支（或 init.janet）就會**自動探測一次**使用者的 endpoint 設定檔。
#   沒有設定檔是正常狀態，不會有任何輸出、也不會報錯。
#   只 import registry.janet 的人不會觸發自動載入 —— 那是刻意的，讓純函式那層保持乾淨。

(import ./defaults :prefix "" :export true)
(import ./builtin  :prefix "" :export true)
(import ./spec     :prefix "" :export true)
(import ./registry :prefix "" :export true)
(import ./resolve  :prefix "" :export true)
(import ./config   :prefix "" :export true)

# ★ 副作用只有這一行：有設定檔就載進 registry，沒有就當沒事發生。
(autoload-endpoints!)
