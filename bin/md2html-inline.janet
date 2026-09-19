# md2html-inline：行內語法 → HTML。code span、**粗體**、[連結](url)、<autolink>、
# 行內 HTML 標籤與註解原樣放行，其餘 & < > 逃逸。純函式；連結怎麼改寫由呼叫端傳 link-fn。

(defn esc "逃逸 & < >" [s]
  (->> s (string/replace-all "&" "&amp;")
       (string/replace-all "<" "&lt;") (string/replace-all ">" "&gt;")))

(defn esc-attr "屬性值：多逃逸雙引號" [s] (string/replace-all "\"" "&quot;" (esc s)))

(defn- run-len "從 i 起連續幾個位元組等於 c" [s i c]
  (var j i) (while (and (< j (length s)) (= (s j) c)) (++ j)) (- j i))

(defn- find-close "找下一個長度剛好 n 的反引號串，回起點或 nil" [s from n]
  (var i from) (var found nil)
  (while (and (nil? found) (< i (length s)))
    (if (= (s i) 96)
      (let [r (run-len s i 96)] (if (= r n) (set found i) (+= i r)))
      (++ i)))
  found)

(defn- find-bold-close "找不在 code span 裡的下一個 **" [s from]
  (var i from) (var found nil) (def n (length s))
  (while (and (nil? found) (< i n))
    (def c (s i))
    (cond
      (= c 96) (let [r (run-len s i 96) cl (find-close s (+ i r) r)]
                 (set i (if cl (+ cl r) (+ i r))))
      (and (= c 42) (= (get s (inc i)) 42)) (set found i)
      (++ i)))
  found)

(defn- trim-span "CommonMark：內容首尾各有一個空白就各去一個" [t]
  (if (and (> (length t) 2) (= (t 0) 32) (= (t (dec (length t))) 32)
           (string/find (string/from-bytes 32) t)
           (not= (length (string/trim t)) 0))
    (string/slice t 1 -2) t))

# 以 ($) 取結尾位置：比對成功回 @[end]
(def- tag-peg (peg/compile
  ~(* "<" (? "/") (range "az" "AZ") (any (range "az" "AZ" "09"))
      (? (* (some :s) (any (if-not ">" 1)))) (? "/") ">" ($))))
(def- comment-peg (peg/compile ~(* "<!--" (any (if-not "-->" 1)) "-->" ($))))
(def- auto-peg (peg/compile
  ~(* "<" (<- (* (+ "http://" "https://" "mailto:") (some (if-not (set "> ") 1)))) ">" ($))))

(defn- punct? [c] (and c (< 32 c 127) (not (or (<= 48 c 57) (<= 65 c 90) (<= 97 c 122)))))

(defn- link-at "在 i（一個 [）試著切出 [text](url)，回 [text url end] 或 nil" [s i]
  (var depth 1) (var j (inc i)) (def n (length s))
  (while (and (< j n) (> depth 0))
    (case (s j) 91 (++ depth) 93 (-- depth))
    (++ j))
  (when (and (= depth 0) (< j n) (= (s j) 40))
    (when-let [close (string/find ")" s j)]
      (def url (string/slice s (inc j) close))
      (unless (string/find "\n" url)
        [(string/slice s (inc i) (- j 1)) url (inc close)]))))

(defn inline->html
  "行內 markdown → HTML 字串。link-fn: url → href（回 nil 就原樣）"
  [s &opt link-fn]
  (default link-fn (fn [u] u))
  (def out @"") (def n (length s)) (var i 0)
  (while (< i n)
    (def c (s i))
    (cond
      (= c 96)
      (let [r (run-len s i 96) close (find-close s (+ i r) r)]
        (if close
          (do (buffer/push out "<code>" (esc (trim-span (string/slice s (+ i r) close))) "</code>")
              (set i (+ close r)))
          (do (buffer/push out (string/slice s i (+ i r))) (+= i r))))
      (and (= c 42) (= (get s (inc i)) 42))
      (let [close (find-bold-close s (+ i 2))]
        (if (and close (> close (+ i 2)))
          (do (buffer/push out "<b>" (inline->html (string/slice s (+ i 2) close) link-fn) "</b>")
              (set i (+ close 2)))
          (do (buffer/push out "**") (+= i 2))))
      (= c 91)
      (if-let [[text url end] (link-at s i)]
        (do (buffer/push out "<a href=\"" (esc-attr (or (link-fn url) url)) "\">"
                         (inline->html text link-fn) "</a>")
            (set i end))
        (do (buffer/push out "[") (++ i)))
      (= c 60)
      (cond
        (peg/match auto-peg s i)
        (let [[url end] (peg/match auto-peg s i)]
          (buffer/push out "<a href=\"" (esc-attr url) "\">" (esc url) "</a>") (set i end))
        (or (peg/match tag-peg s i) (peg/match comment-peg s i))
        (let [[end] (or (peg/match tag-peg s i) (peg/match comment-peg s i))]
          (buffer/push out (string/slice s i end)) (set i end))
        (do (buffer/push out "&lt;") (++ i)))
      (= c 38) (do (buffer/push out "&amp;") (++ i))
      (= c 62) (do (buffer/push out "&gt;") (++ i))
      (and (= c 92) (punct? (get s (inc i))))
      (do (buffer/push out (esc (string/from-bytes (s (inc i))))) (+= i 2))
      (do (buffer/push out (string/from-bytes c)) (++ i))))
  (string out))

(defn strip-inline
  "去掉行內標記留純文字（給 <title>、摘要用）：反引號、**、連結只留字、標籤去掉"
  [s]
  (def out @"") (def n (length s)) (var i 0)
  (while (< i n)
    (def c (s i))
    (cond
      (= c 96) (+= i (run-len s i 96))
      (and (= c 42) (= (get s (inc i)) 42)) (+= i 2)
      (= c 91) (if-let [[text url end] (link-at s i)]
                 (do (buffer/push out (strip-inline text)) (set i end))
                 (do (buffer/push out "[") (++ i)))
      (and (= c 60) (or (peg/match tag-peg s i) (peg/match comment-peg s i)))
      (set i (first (or (peg/match tag-peg s i) (peg/match comment-peg s i))))
      (do (buffer/push out (string/from-bytes c)) (++ i))))
  (string/trim (string out)))
