# CLI 這一層 —— 決定「哪些旗標本殼要吃掉、哪些原樣透傳」。
#
# 從 main.janet 拆出來的理由只有一個：**讓這段判斷可以離線測**（take-flags 是純函式）。
#
# ── 透傳殼的紀律 ────────────────────────────────────────────────────
# 本殼消化掉的旗標愈少愈好——多吃一個，子行程就少一個能用的旗標。所以規則是：
#
#   * `--claude`  —— 出現在**任何位置**都會被吃掉（沿用原本的行為，不改）
#   * 其餘本殼自己的旗標**只在第一個參數的位置**才算數：
#       --agent <名字>     用 registry 裡的某支 agent
#       --agent-file <檔>  先載入一份 agent 設定檔
#       --list-agents      列出 registry 裡有哪些 agent 就結束
#     放在後面的一律原樣往下透傳。
#     ⚠ 這條「只認第一個位置」的規則是刻意的：`claude` 自己就有 `--agents` 旗標，
#       如果本殼在任何位置都攔截，使用者就再也沒辦法把它送給 claude 了。
#
# 其餘（--model／--no-tools／--allowedTools／--output-format／@file…，連 --help）
# 一律讓給子行程。

(import ./agents :as ag)
(import ./config :as conf)

(defn take-flags
  ``把本殼要消化的旗標從參數陣列挑出來。**純函式**，不做任何 IO。

  回 @{:args 剩下要透傳的參數
       :agent 要跑哪支（名字字串，預設 "pi"）
       :agent-files 要載入的設定檔陣列
       :list? 是不是只要列出 agent}

  規則見本檔開頭。``
  [args]
  (def out @{:args @[] :agent "pi" :agent-files @[] :list? false})
  (var i 0)
  # ── 只認第一個位置的那幾個 ──────────────────────────────────────
  (while (< i (length args))
    (def a (get args i))
    (cond
      (= a "--list-agents")
      (do (put out :list? true) (++ i))

      (= a "--agent")
      (do (put out :agent (or (get args (inc i))
                              (error "--agent 後面要接 agent 名字（--list-agents 看有哪些）")))
          (+= i 2))

      (= a "--agent-file")
      (do (array/push (out :agent-files)
                      (or (get args (inc i))
                          (error "--agent-file 後面要接設定檔路徑")))
          (+= i 2))

      (break)))

  # ── --claude：任何位置都吃掉（只吃第一個）─────────────────────────
  (var took-claude false)
  (each a (slice args i)
    (if (and (not took-claude) (= a "--claude"))
      (do (set took-claude true) (put out :agent "claude"))
      (array/push (out :args) a)))
  out)

(defn list-text
  "--list-agents 印的東西，回一整段字串。"
  []
  (def out @["registry 裡的 agent（<cmd> -p <args...> 形狀的非互動 CLI）"])
  (each n (ag/agent-names)
    (def s (get ag/agent-specs n))
    (array/push out
                (string/format "  %-12s cmd=%-10s %s%s"
                               n (s :cmd)
                               (if (s :prompt-flag)
                                 (string "非互動旗標=" (s :prompt-flag))
                                 "（不墊非互動旗標）")
                               (if (s :model-flag)
                                 (string "  model 旗標=" (s :model-flag)) "")))
    (when-let [note (s :note)]
      (array/push out (string/format "               %s" note)))
    (array/push out
                (string/format "               來源：%s"
                               (case (ag/agent-source n)
                                 :builtin "內建"
                                 :runtime "程式裡 define-agent 註冊的"
                                 (ag/agent-source n)))))
  (array/push out
              (string "\n要加自己的：寫一份 agent 設定檔（範本見 modules/pi-shell/agents.example.janet），\n"
                      "放到下列任一位置會自動載入，或用 --agent-file <檔案> 明確指定——\n"
                      (string/join (map |(string "  " $) (conf/config-candidates)) "\n")))
  (if (empty? conf/loaded-files)
    (array/push out "目前沒載到任何設定檔。")
    (array/push out (string "已載入：" (string/join conf/loaded-files " "))))
  (string/join out "\n"))
