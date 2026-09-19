# 配合 docs/44、44b（從 Lua 過來的逐條對照）
#
#   janet examples/compare-lua.janet
#
# 每列印「Lua 的寫法 → Janet 的寫法 → 實際結果」。Lua 那欄只是註解，不會真的跑。

(import spork/path :as p)

(defn 節 [t] (print "\n── " t " ─────────────────────"))
(defn 顯示 [r] (if (string? r) (string "\"" r "\"") (string/format "%j" r)))   # 字串直接印，%j 會把中文逃逸
(defn 列 [lua j r] (printf "  %-30s %-38s => %s" lua j (顯示 r)))
(defn 錯 [f] (try (do (f) :沒報錯) ([e] (string "錯：" e))))

(節 "索引從 0 起、越界給 nil")
(列 "t[1]" "(get [10 20 30] 0)" (get [10 20 30] 0))
(列 "t[#t]" "(last [10 20 30])" (last [10 20 30]))
(列 "t[4]  越界" "(get [10 20 30] 3)" (get [10 20 30] 3))
(列 "t[-1]  （Lua 也是 nil）" "(get [10 20 30] -1)  ⚠ 不是從尾數" (get [10 20 30] -1))
(列 "（要報錯版）" "(in [10 20 30] -1)" (錯 |(in [10 20 30] -1)))

(節 "nil、false、#")
(列 "if 0 then  （真）" "(if 0 :真 :假)" (if 0 :真 :假))
(列 "t.a = nil  刪 key" "(put @{:a 1 :b 2} :a nil)" (put @{:a 1 :b 2} :a nil))
(列 "#{1, nil, 3}  不可靠" "(length @[1 nil 3])" (length @[1 nil 3]))
(列 "#{a=1, b=2}  是 0" "(length @{:a 1 :b 2})" (length @{:a 1 :b 2}))

(節 "多重回傳、...、unpack")
(defn divmod [a b] [(div a b) (% a b)])
(def [q r] (divmod 7 2))
(列 "local q, r = divmod(7, 2)" "(def [q r] (divmod 7 2))" [q r])
(def [a b c] [1 2])
(列 "local a, b, c = 1, 2" "(def [a b c] [1 2])" [a b c])
(defn f [& rest] [(length rest) rest])
(列 "select('#', ...), {...}" "(defn f [& rest] [(length rest) rest])" (f 1 2))
(defn g [x y z] [x y z])
(列 "g(table.unpack(t))" "(g ;[1 2 3])" (g ;[1 2 3]))

(節 "字串")
(列 "s:sub(2, 3)" "(string/slice \"hello\" 1 3)" (string/slice "hello" 1 3))
(列 "s:sub(-3)" "(string/slice \"hello\" -3)" (string/slice "hello" -3))
(列 "s:byte(1)" "(get \"abc\" 0)" (get "abc" 0))
(列 "string.char(97)" "(string/from-bytes 97)" (string/from-bytes 97))
(列 "s:find('l', 1, true)" "(string/find \"l\" \"hello\")  ⚠ 順序反" (string/find "l" "hello"))
(列 "s:gsub('l', 'L')" "(string/replace-all \"l\" \"L\" \"hello\")" (string/replace-all "l" "L" "hello"))
(列 "'a' .. 1 .. 2.5" "(string \"a\" 1 2.5)" (string "a" 1 2.5))
(列 "'1' + 1  → 2" "(+ \"1\" 1)  ⚠ 不轉型" (錯 |(+ "1" 1)))
(列 "tonumber('abc')" "(scan-number \"abc\")" (scan-number "abc"))
(列 "tostring(nil)  → 'nil'" "(string nil)  ⚠ 是空字串" (string nil))

(節 "算術")
(列 "-7 // 2" "(div -7 2)" (div -7 2))
(列 "-7 % 2  → 1" "(mod -7 2)" (mod -7 2))
(列 "（C 那種餘數）" "(% -7 2)  ⚠ 不是 Lua 的 %" (% -7 2))
(列 "2 ^ 10" "(math/pow 2 10)" (math/pow 2 10))
(列 "1 ~= 2" "(not= 1 2)" (not= 1 2))

(節 "閉包、全域")
(var n 0)
(defn inc! [] (++ n))
(inc!) (inc!)
(列 "upvalue n = n + 1" "(var n 0) … (++ n)" n)
(列 "x = 1  忘了 local → 全域" "(set undefined-name 1)" (錯 |(eval-string "(set undefined-name 1)")))

(節 "metatable → prototype")
(def Animal @{:speak (fn [self] (string (self :name) " says hi"))})
(def d (table/setproto @{:name "dog"} Animal))
(列 "setmetatable(d, {__index=Animal})" "(table/setproto d Animal)" (:speak d))
(列 "rawget(d, 'speak')" "(table/rawget d :speak)" (table/rawget d :speak))
(列 "__add" "(+ @{:v 1} @{:v 2})  ⚠ 沒有運算子重載" (錯 |(+ @{:v 1} @{:v 2})))
(列 "__tostring" "(string @{:a 1})  ⚠ 沒有" (string @{:a 1}))

(節 "pcall、error")
(列 "pcall(error, 'boom')" "(protect (error \"boom\"))" (protect (error "boom")))
(列 "pcall(function() return 2 end)" "(protect 2)" (protect 2))
(列 "error({code=42})" "(try (error {:code 42}) ([e] (e :code)))" (try (error {:code 42}) ([e] (e :code))))

(節 "coroutine → fiber")
(def co (coro (yield 1) (yield 2) 3))
(列 "resume/status ×3" "(resume co) (fiber/status co) …"
    [(resume co) (fiber/status co) (resume co) (resume co) (fiber/status co)])
(列 "resume 死掉的" "(resume co)" (錯 |(resume co)))
(列 "for x in coroutine.wrap(f)" "(seq [x :in (coro …)] x)" (seq [x :in (coro (yield :a) (yield :b))] x))

(節 "require、ipairs、pairs")
(列 "local p = require 'spork.path'" "(import spork/path :as p)  只能頂層" (p/join "a" "b"))
(def r1 @[]) (eachp [i v] @[:a :b] (array/push r1 [i v]))
(列 "for i, v in ipairs(t)" "(eachp [i v] t …)" r1)
(def r2 @[]) (eachp [k v] @{:x 1} (array/push r2 [k v]))
(列 "for k, v in pairs(t)" "(eachp [k v] t …)" r2)
(列 "pairs 順序不保證" "(keys @{:b 1 :a 2 :c 3})" (keys @{:b 1 :a 2 :c 3}))

(print "\n✓ compare-lua 跑完——goto continue 那些在 docs/01d")
