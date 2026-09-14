#!/usr/bin/env janet
# image 全程走一遍：存（make-image）→ 讀（load-image）→ fiber 續跑 → 存不了的東西
# → 命令列的 janet -c / -i → import 找到的是 .jimage 還是 .janet。
# 跑法：janet examples/image-tour.janet   （會在暫存目錄寫幾個檔，跑完自己刪）
# 詳解見 docs/16b-image-存成檔.md、docs/16c-image-怎麼用.md

(def tmp (string (or (os/getenv "TMPDIR") (os/getenv "TEMP") "/tmp") "/janet-image-tour"))
(os/mkdir tmp)
(defn path [name] (string tmp "/" name))
(defn run [& argv] (print "$ " (string/join argv " ")) (flush) (os/execute argv :p))

# ── 1) image 就是「用 root-env 當查找表的 marshal」───────────────────
(def env @{'greeting @{:value "哈囉"}
           'shout @{:value (fn [s] (string/ascii-upper s))}})
(def img (make-image env))
(printf "1) make-image 給的是 %s，%d bytes" (type img) (length img))
(def back (load-image img))
(printf "   load-image 還原：greeting=%s，(shout \"hi\")=%q"
        (get-in back ['greeting :value]) ((get-in back ['shout :value]) "hi"))
(printf "   同一件事用 marshal 寫：%q"
        (= (string img) (string (marshal env make-image-dict))))

# ── 2) 把「跑到一半」的當前環境存成檔 ─────────────────────────────────
(def counter @{:n 0})
(defn bump [] (++ (counter :n)))
(bump) (bump) (bump)
(spit (path "snap.jimage") (make-image (curenv)))
(def snap (load-image (slurp (path "snap.jimage"))))
(printf "\n2) 存檔時 n=%d；讀回來 env 裡有：%q"
        (get-in snap ['counter :value :n]) (sort (filter symbol? (keys snap))))
(print "   一個綁定長這樣：" (string/format "%q" (snap 'counter)))

# ── 3) fiber 暫停中也存得下，讀回來從斷點續跑 ───────────────────────
(defn work [] (var acc 0) (for i 0 6 (+= acc i) (yield [i acc])))
(def job (fiber/new work))
(def before (seq [_ :range [0 3]] (resume job)))
(spit (path "job.jimage") (make-image @{'job @{:value job}}))
(def job2 (get-in (load-image (slurp (path "job.jimage"))) ['job :value]))
(printf "\n3) 存檔前跑了 %q（status %q）" before (fiber/status job))
(printf "   讀回的 fiber status %q，續跑：%q %q" (fiber/status job2) (resume job2) (resume job2))

# ── 4) 存不了的東西：OS 資源、native 模組的 cfunction ────────────────
(print "\n4) 存不了的東西")
(with [f (file/open (path "snap.jimage"))]
  (try (make-image @{'f @{:value f}}) ([e] (print "   file handle → " e))))
(import spork/json)
(try (make-image (curenv)) ([e] (print "   env 裡 import 了 spork/json → " e)))
(print "   純 Janet 的 spork/path 就沒事：" (length (make-image (require "spork/path"))) " bytes")

# ── 5) 命令列：janet -c 編、janet -i 跑 ──────────────────────────────
(print "\n5) janet -c / -i")
(spit (path "hello.janet") ```
(print "頂層這行：-c 時印，-i 時不印")
(def built-at (os/time))
(defn main [& args] (printf "main 收到 %q，built-at 距現在 %d 秒" args (- (os/time) built-at)))
```)
(run "janet" "-c" (path "hello.janet") (path "hello.jimage"))
(run "janet" "-i" (path "hello.jimage") "x" "y")
(print)
(print "   沒有 -i 會被當原始碼 parse：")
(run "janet" (path "hello.jimage"))
(print)

# ── 6) import 先找 .jimage，而且不比時間戳 ───────────────────────────
(print "6) import 的優先順序")
(spit (path "mod.janet") "(def version :v1)")
(os/execute ["janet" "-c" (path "mod.janet") (path "mod.jimage")] :p)
(spit (path "mod.janet") "(def version :v2)")   # 原始碼改了，image 沒重編
(def m (with-dyns [:current-file (path "here.janet")] (require "./mod")))   # 相對「目前檔案」
(printf "   原始碼寫 :v2，import 拿到 %q（來自 %q）"
        (get-in m ['version :value]) (first (filter |(string/has-suffix? "mod.jimage" $) (keys module/cache))))

(each f (os/dir tmp) (os/rm (path f)))
(os/rmdir tmp)
(print "\n暫存檔已清掉。")
