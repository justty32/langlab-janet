# md2html-hl：Janet 程式碼最簡單的語法上色（關鍵字／字串／註解／數字），沿用 style.css 的
# .kw .str .cmt .num。逐位元組掃描，不求完整，只求常見寫法看起來對。純函式。

(import ./md2html-inline :as inl)

(def keywords
  "會上 .kw 的符號：特殊形式與最常見的核心巨集（含 ( 一起包，跟手寫速查表一致）"
  (invert ["def" "var" "fn" "do" "if" "while" "break" "quote" "quasiquote" "unquote" "splice"
           "set" "upscope" "defn" "defn-" "def-" "var-" "varfn" "defmacro" "defmacro-" "let"
           "when" "unless" "cond" "case" "loop" "seq" "for" "forv" "each" "eachp" "eachk"
           "generate" "try" "defer" "protect" "with" "with-dyns" "with-syms" "match" "import"
           "use" "require" "default" "label" "prompt" "yield" "coro" "if-let" "when-let"
           "if-not" "when-not" "defdyn" "assert" "error" "errorf" "short-fn" "toggle" "edefer"]))

(defn- sym-char? [c]
  (and c (not (or (<= c 32) (= c 40) (= c 41) (= c 91) (= c 93) (= c 123) (= c 125)
                  (= c 34) (= c 59) (= c 35) (= c 96) (= c 44) (= c 39) (= c 126)))))

(defn- digit? [c] (and c (<= 48 c 57)))

(defn- number-at "i 處是不是數字字面值（前面得是分隔），回結尾" [s i]
  (def c (s i)) (def prev (get s (dec i)))
  (when (and (or (digit? c) (and (or (= c 45) (= c 43)) (digit? (get s (inc i)))))
             (not (sym-char? prev)))
    (var j (inc i))
    (while (sym-char? (get s j)) (++ j))
    (when (peg/match ~(* (? (set "-+")) (+ (* :d+ (? (* "." :d*))) (* "." :d+)) (any (+ :w (set "_.")))) (string/slice s i j))
      j)))

(defn highlight "Janet 原始碼 → 帶 span 的 HTML（內容已逃逸）" [src]
  (def out @"") (def n (length src)) (var i 0)
  (defn span [cls from to] (buffer/push out "<span class=\"" cls "\">" (inl/esc (string/slice src from to)) "</span>"))
  (while (< i n)
    (def c (src i))
    (cond
      (= c 35)
      (let [e (or (string/find "\n" src i) n)] (span "cmt" i e) (set i e))
      (= c 34)
      (do (var j (inc i))
          (while (and (< j n) (not= (src j) 34)) (if (= (src j) 92) (+= j 2) (++ j)))
          (span "str" i (min n (inc j))) (set i (min n (inc j))))
      (= c 96)
      (do (var r 0) (while (= (get src (+ i r)) 96) (++ r))
          (def close (string/find (string/slice src i (+ i r)) src (+ i r)))
          (def e (if close (+ close r) n))
          (span "str" i e) (set i e))
      (and (= c 40) (sym-char? (get src (inc i))))
      (do (var j (inc i)) (while (sym-char? (get src j)) (++ j))
          (def word (string/slice src (inc i) j))
          (if (keywords word) (do (span "kw" i j) (set i j))
            (do (buffer/push out "(") (++ i))))
      (number-at src i)
      (let [e (number-at src i)] (span "num" i e) (set i e))
      (sym-char? c)
      (do (var j i) (while (sym-char? (get src j)) (++ j))
          (buffer/push out (inl/esc (string/slice src i j))) (set i j))
      (do (buffer/push out (inl/esc (string/from-bytes c))) (++ i))))
  (string out))
