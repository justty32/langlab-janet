# 對話層 —— 「一個 bot ＝ 一段對話」，把 messages 的組裝與記憶收在這裡。
#
# 下面那層（HTTP 怎麼送、錯誤怎麼分類）在 transport.janet；這一層不碰 http、
# 不碰 json，只管**語意**：system 擺哪、history 什麼時候寫、答案從哪裡挖。
#
# bot 就是一張看得見的 table，沒有藏東西——除錯時直接 (pp bot) 看 history。
# 而且它剛好也是 transport 要的 cfg（:url / :api-key 兩個欄位就在裡面），
# 所以 post-chat 直接收 bot，不用另外組一份設定。

(import ./transport :as tp)

(defn new
  ``開一段新對話。回傳的 table 就是這段對話的全部狀態。

  :model    預設用哪顆模型（ask 可以逐次覆寫）
  :system   人設。**不佔 history**，每次送出時才臨時補在最前面
  :url      不給就用 transport 的預設（本機 litellm proxy）
  :api-key  不給就用 transport 的 "dummy"``
  [&named model system url api-key]
  # ⚠ :history 一定要在這裡建。放進某張共用的表就會變成所有 bot 共用同一個
  #   array，症狀是「它記得我沒說過的話」，而且非常難聯想。
  @{:model   model
    :system  system
    :url     url
    :api-key api-key
    :history @[]})

(defn reset
  ``清掉對話歷史，但**不動 system**。回傳 bot 本身，方便串接。

  system 存在 bot 上而不是塞進 history，就是為了讓這件事講得通：
  「換個話題重來，但人設留著」。``
  [bot]
  (array/clear (bot :history))
  bot)

(defn- build-messages
  ``組出這次要送的 messages：[system?] ++ history ++ [這則 user]。

  注意它**不寫 history**——只是臨時拼一份出來。history 要等 post-chat
  真的成功了才由 ask 寫回去（理由見 ask 裡那段註解）。``
  [bot user-msg]
  (def messages @[])
  (when-let [sys (bot :system)]
    (unless (empty? sys)
      (array/push messages {:role "system" :content sys})))
  (array/concat messages (bot :history))
  (array/push messages user-msg)
  messages)

(defn ask
  ``問一句，拿字串答案回來。bot 的 history 會被就地更新。

  :model     這一次改用別顆模型，對話不中斷（優先序：這裡 ＞ bot 的 :model）
  :remember  給 false 的話，這一問一答都不寫進 history

  失敗時一律丟例外（訊息由 transport 那層給），而且**保證不動 history**。``
  [bot prompt &named model remember]
  (def use-model (or model (bot :model)))
  (unless use-model
    (error "這個 bot 沒有 :model —— 不知道要跟哪顆模型講話"))

  (def user-msg @{:role "user" :content prompt})
  (def res
    (tp/post-chat bot @{:model    use-model
                        :messages (build-messages bot user-msg)}))

  (def reply (get-in res [:choices 0 :message]))
  (unless reply
    (error (string/format "回應裡沒有 choices[0].message：%q" res)))
  (def text (reply :content))
  (unless (string? text)
    (error (string/format "答案不是字串（模型可能只回了 tool_calls）：%q" reply)))

  # ⚠ 推理模型會把 token 預算全花在 reasoning 上，content 回空字串、HTTP 仍是 200。
  #   ask 承諾回答案，這種情況直接講清楚，別讓呼叫端拿到 "" 以為模型沒話說。
  #   （這條的完整實測見 FINDINGS-踩坑.md 第十節。）
  (when (and (empty? text) (= "length" (get-in res [:choices 0 :finish_reason])))
    (error (string/format
             (string "答案被截斷了（finish_reason=length），content 是空字串。\n"
                     "推理模型會先花掉 reasoning tokens，預算太小就什麼都印不出來。\n"
                     "這次用量：%q")
             (get res :usage))))

  # ★ 到這裡才寫 history，順序是刻意的。
  #   先推 user 再送出的話，post-chat 一失敗就會在 history 裡留下一則**沒有回應的
  #   孤兒 user 訊息**，之後每一輪都把它送出去（user, user, assistant…），
  #   有些後端直接 400、有些是默默答歪，而你只會覺得模型突然變笨了。
  #
  #   存的是**整則 message table 不是字串**：第 6 步做 tool loop 時 assistant 那則
  #   會帶 :tool_calls，只存 content 就把它弄丟了。
  (unless (= remember false)
    (array/push (bot :history) user-msg)
    (array/push (bot :history) reply))

  text)
