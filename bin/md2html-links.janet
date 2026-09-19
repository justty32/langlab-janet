# md2html-links：路徑運算與連結改寫。所有路徑一律用 / 分段、以 repo 根為基準（可含開頭的 ..）。
# 規則：.md 且有產生頁 → 對應 html/… 的 .html；本來就指 html/ → 原頁；其他（.janet、目錄、外部檔）
# → 指向 repo 內原檔的相對路徑，維持可點。http(s)/mailto/純 #錨點 不動。

(defn split-path [p] (filter |(not= $ "") (string/split "/" p)))

(defn normalize "去掉 . 與 ..（.. 超出根就留著）" [segs]
  (def out @[])
  (each s segs
    (cond (= s ".") nil
          (= s "..") (if (and (> (length out) 0) (not= (last out) "..")) (array/pop out) (array/push out ".."))
          (array/push out s)))
  out)

(defn join-path [segs] (string/join segs "/"))
(defn dirname [p] (join-path (array/slice (split-path p) 0 -2)))
(defn basename [p] (last (split-path p)))

(defn resolve "從 from-file 所在目錄看 rel，回正規化後的 repo 相對路徑" [from-file rel]
  (join-path (normalize (array/concat (array/slice (split-path from-file) 0 -2) (split-path rel)))))

(defn relpath "從目錄 from-dir 走到 target 的相對路徑（兩者都是 repo 相對）" [from-dir target]
  (def a (normalize (split-path from-dir))) (def b (normalize (split-path target)))
  (var k 0)
  (while (and (< k (length a)) (< k (length b)) (= (a k) (b k)) (not= (a k) "..")) (++ k))
  (def ups (seq [_ :range [k (length a)]] ".."))
  (def rest (array/slice b k))
  (def segs (array/concat ups rest))
  (if (empty? segs) "." (join-path segs)))

(defn md->html-path "docs/01-x.md → html/docs/01-x.html" [md]
  (string "html/" (string/slice md 0 -4) ".html"))

(defn external? [url]
  (or (string/has-prefix? "http://" url) (string/has-prefix? "https://" url)
      (string/has-prefix? "mailto:" url) (string/has-prefix? "#" url) (string/find ":" (string/slice url 0 (or (string/find "/" url) -1)))))

(defn split-frag "url → [path frag-with-#]" [url]
  (if-let [h (string/find "#" url)] [(string/slice url 0 h) (string/slice url h)] [url ""]))

(defn rewrite
  "把 src-md 裡的 url 改成從 out-page 所在目錄可用的 href。
   pages：有產生的 md 集合（table，key 是 repo 相對路徑）。
   回 {:href :target :kind}，kind ∈ :page（產生頁）:html（既有速查表）:raw（原檔）:ext（外部）"
  [url src-md pages]
  (if (or (external? url) (= url ""))
    {:href url :target nil :kind :ext}
    (let [[path frag] (split-frag url)
          target (if (= path "") src-md (resolve src-md path))
          out-dir (dirname (md->html-path src-md))
          kind (cond (pages target) :page (string/has-prefix? "html/" target) :html :raw)
          dest (case kind :page (md->html-path target) target)
          href (string (relpath out-dir dest) (if (string/has-suffix? "/" path) "/" "") frag)]
      {:href href :target dest :kind kind :frag frag})))

(defn depth-prefix "html/docs/x.html 回 ../ ；html/x.html 回空字串" [out-page]
  (string/repeat "../" (- (length (split-path out-page)) 2)))
