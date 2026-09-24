# 配合 course/9-2-jpm-專案.md：最小可 jpm test、jpm build 的專案
(declare-project
  :name "demo"
  :description "課程單元 9 的示範專案"
  :version "0.1.0"
  :dependencies ["spork"])

(declare-source
  :prefix "demo"
  :source ["demo/init.janet"])

(declare-executable
  :name "demo"
  :entry "bin/main.janet"
  :install false)
