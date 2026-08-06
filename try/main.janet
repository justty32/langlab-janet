(setdyn :current-file "try/main.janet")
(import ./transport :as tp)

(def cfg {:api-key "dummy"})

(def res
  (tp/post-chat cfg {
    :model "ollama-gemma3-1b"                 
    :messages [
        {:role "user" :content "hello"}       
    ]
  }))

(print (get-in res [:choices 0 :message :content]))