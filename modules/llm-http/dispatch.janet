# 派送 —— 一份 OpenAI 形狀的 payload 該送去哪、要不要重試，只決定這件事。
#
#   :api :anthropic → provider-anthropic/post-anthropic（本機轉 Messages API 再轉回來）
#   其他            → transport/post-chat（OpenAI 相容端點；http 走 spork、https 走 curl）
#
# chat.janet 只叫 send-chat，不認識任何 provider；要再加一家 provider 就在這裡多一個分支。

(import ./transport :as tp)
(import ./provider-anthropic :as anth)
(import ./retry)

(defn send-chat
  ``送出 payload，回 OpenAI 形狀的回應。

  retry —— nil／0 只送一次；數字 n 表示失敗時最多**多試** n 次（只對連不上／5xx／429，
  指數退避）；也可以給 {:times n :base 秒 :on-retry (fn [n err wait])}。``
  [cfg payload &opt retry-spec]
  (def send
    (if (anth/anthropic? cfg)
      (fn [] (anth/post-anthropic cfg payload))
      (fn [] (tp/post-chat cfg payload))))
  (if (or (nil? retry-spec) (= 0 retry-spec))
    (send)
    (retry/with-retry retry-spec send)))
