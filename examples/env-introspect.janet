#!/usr/bin/env janet
# env 自省：列出環境裡有什麼、查某個 symbol 是什麼、切換到別的 env 求值。
# 跑法：janet examples/env-introspect.janet
# 詳解見 docs/12-env-環境與動態變數.md

(defn h [s] (printf "\n=== %s" s))

# 本檔自己定義幾個不同種類的綁定，等下拿來查
(def  a-const 42)
(var  a-var 1)
(defn a-fn "docstring goes here" [x] x)
(defmacro a-macro [] 1)
(def- a-private 7)
(setdyn :my-setting "本來的值")

# ── 1) 環境表就是一張 table：symbol key 是綁定、keyword key 是動態變數 ──
(h "(curenv) 的兩種 key")
(printf "  type                    => %q" (type (curenv)))
(printf "  是本 fiber 的 env？     => %q" (= (curenv) (fiber/getenv (fiber/current))))
(printf "  symbol key  'a-const    => %q" (get (curenv) 'a-const))
(printf "  keyword key :my-setting => %s" (get (curenv) :my-setting))

# ── 2) 列出「這張表自己有的」名字（不含從 core 繼承來的 700 多個）──────
(h "列出本層定義的所有 symbol")
(pp (sort (all-bindings (curenv) true)))   # local=true 才不會把 core 一起倒出來

(h "列出本層的動態變數")
(pp (sort (all-dynamics (curenv) true)))

(h "全部（含繼承）有幾個")
(printf "  all-bindings => %d 個 symbol" (length (all-bindings)))
(printf "  all-dynamics => %q" (sort (all-dynamics)))

# ── 3) 查某個 symbol 是什麼 ─────────────────────────────────────────────
(defn what-is
  "回答 sym 在 env 裡是什麼東西：巨集 / var / 值的型別 / 沒定義。"
  [env sym]
  (def b (get env sym))
  (cond
    (nil? b)   :未定義
    (b :macro) :macro
    (b :ref)   :var            # var 的值裝在 :ref 這個長度 1 的 array 裡
    (type (b :value))))

(h "某個 symbol 是什麼型別")
(each s '[a-const a-var a-fn a-macro a-private map printf no-such-name]
  (printf "  %-12s => %q" (string s) (what-is (curenv) s)))

(h "綁定的完整 meta")
(each s '[a-var a-fn a-private]
  (printf "  %-10s %q" (string s) (get (curenv) s)))

(h "取出實際的值")
(printf "  def => %q" ((get (curenv) 'a-const) :value))
(printf "  var => %q" (first ((get (curenv) 'a-var) :ref)))

# ── 4) 動態變數的作用域 ─────────────────────────────────────────────────
(h "dyn / setdyn / with-dyns")
(printf "  現在         => %s" (dyn :my-setting))
(with-dyns [:my-setting "暫時蓋掉"]
  (printf "  with-dyns 內 => %s" (dyn :my-setting)))
(printf "  離開之後     => %s" (dyn :my-setting))
(printf "  沒設過的     => %q" (dyn :never-set :這是預設值))

# ── 5) ★ fiber 的 env 預設是 nil，不是繼承 ──────────────────────────────
(h "fiber 的 env")
(def f (fiber/new (fn [] (printf "  fiber/new 內看得到嗎？ %q" (dyn :my-setting)))))
(resume f)                                   # => nil，看不到
(def g (fiber/new (fn [] (printf "  setenv 之後呢？        %s" (dyn :my-setting)))))
(fiber/setenv g (curenv))                    # 換掉它的 env → 看得到了
(resume g)
(ev/spawn (printf "  ev/spawn 會繼承：      %s" (dyn :my-setting)))
(ev/sleep 0)

# ── 6) 切換 env：在一張乾淨的表裡求值，不污染這裡 ───────────────────────
(h "在指定 env 裡求值")
(def sandbox (make-env))
(def worker (fiber/new (fn [] (eval-string "(def secret 7) (* secret 6)"))))
(fiber/setenv worker sandbox)
(printf "  求值結果        => %q" (resume worker))
(printf "  沙箱裡有嗎      => %q" (get sandbox 'secret))
(printf "  這裡有嗎        => %q" (get (curenv) 'secret))
(printf "  沙箱自己有什麼  => %q" (sort (all-bindings sandbox true)))

# ── 7) OS 環境變數（跟上面完全無關的另一種 env）─────────────────────────
(h "OS 環境變數")
(printf "  HOME            => %s" (os/getenv "HOME"))
(printf "  沒有的 + 預設   => %s" (os/getenv "NO_SUCH_VAR_XYZ" "這是預設值"))
(printf "  一共            => %d 個" (length (os/environ)))
(os/setenv "MY_VAR" "abc")
(prin "  子行程繼承      => ") (flush) (os/execute ["sh" "-c" "echo $MY_VAR"] :p)
# ★ 第三個參數（環境 table）要有 :e 旗標才生效，只寫 :p 會被安靜忽略
(prin "  :pe 換掉環境    => ") (flush) (os/execute ["sh" "-c" "echo $MY_VAR"] :pe {"MY_VAR" "over"})
(prin "  漏了 e（無效）  => ") (flush) (os/execute ["sh" "-c" "echo $MY_VAR"] :p  {"MY_VAR" "over"})
(os/setenv "MY_VAR" nil)   # 傳 nil = 刪掉
(print)
