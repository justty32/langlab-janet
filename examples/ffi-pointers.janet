#!/usr/bin/env janet
# FFI 進階：型別大小、struct、out 參數、手動記憶體、char* 轉字串。
# 跑法：janet examples/ffi-pointers.janet
# 詳解見 docs/10-c-互通.md「一之二、型別、指標與記憶體」

(def libc (ffi/native "libc.so.6"))

(defn h [s] (printf "\n=== %s" s))

# ── 1) 型別大小：永遠用 ffi/size 問，別用猜的 ────────────────────────────
(h "型別大小 / 對齊")
(each t [:char :int :long :size :double :ptr :string :s64]
  (printf "  %-8s size=%d align=%d" (string t) (ffi/size t) (ffi/align t)))

# ── 2) struct 型別：padding 由 Janet 照 C 規則算 ─────────────────────────
(h "struct / 陣列 / 巢狀")
(def inner (ffi/struct :int :int))
(def outer (ffi/struct inner @[:char 4] :double))   # 陣列型別要用 @[]，不是 []
(printf "  (ffi/struct :char :int :ptr) => size=%d align=%d"
        (ffi/size (ffi/struct :char :int :ptr))
        (ffi/align (ffi/struct :char :int :ptr)))
(printf "  outer                        => size=%d" (ffi/size outer))

# ── 3) ffi/write / ffi/read：Janet 值 ↔ 原始記憶體 ───────────────────────
(h "write / read round-trip")
(def blob (ffi/write outer [[1 2] [97 98 99 0] 3.5]))
(printf "  bytes=%d" (length blob))
(printf "  讀回 => %q" (ffi/read outer blob))

# 附加到既有 buffer，用 offset 讀
(def buf @"")
(ffi/write :int 7 buf)
(ffi/write :int 9 buf)
(printf "  兩個 int 疊在一起：len=%d [0]=%q [4]=%q"
        (length buf) (ffi/read :int buf 0) (ffi/read :int buf 4))

# ── 4) out 參數：把 Janet buffer 當 void* 傳進去讓 C 填 ──────────────────
(h "out 參數：clock_gettime(CLOCK_REALTIME, &ts)")
(def timespec (ffi/struct :long :long))
(def out (buffer/new-filled (ffi/size timespec)))   # ★ new-filled，不是 buffer/new
(def rc (ffi/call (ffi/lookup libc "clock_gettime")
                  (ffi/signature :default :int :int :ptr) 0 out))
(def [sec nsec] (ffi/read timespec out))
(printf "  rc=%d  epoch 秒=%d" rc (int/to-number sec))

# ── 5) struct 傳值回傳：div_t div(int, int) ──────────────────────────────
(h "回傳 struct by value")
(def div-t (ffi/struct :int :int))
(printf "  div(17,5) => %q  (quot, rem)"
        (ffi/call (ffi/lookup libc "div")
                  (ffi/signature :default div-t :int :int) 17 5))

# ── 6) 手動記憶體：malloc / pointer-buffer / free ────────────────────────
(h "ffi/malloc + pointer-buffer（GC 不管，得自己 free）")
(def mem (ffi/malloc 32))
(defer (do (ffi/free mem) (print "  已 ffi/free"))
  (def view (ffi/pointer-buffer mem 32 32 0))   # 把裸記憶體當 buffer 讀寫
  (buffer/blit view "hello\0" 0)
  # :string 參數會自動補結尾的 \0（Janet 字串裡不能自己夾 \0），所以複製 9+1 個位元組
  (ffi/call (ffi/lookup libc "memcpy")
            (ffi/signature :default :ptr :ptr :string :size) mem "hi from C" 10)
  (printf "  memcpy 之後 => %q" (ffi/read :string (ffi/write :ptr mem))))

# ── 7) char* → Janet 字串的兩條路 ────────────────────────────────────────
(h "char* 轉字串")
(def getenv (ffi/lookup libc "getenv"))
# 路一：回傳型別直接寫 :string，Janet 自動轉（★ 但 C 回 NULL 會 segfault）
(printf "  :string 回傳     => %q"
        (ffi/call getenv (ffi/signature :default :string :string) "HOME"))
# 路二：回傳 :ptr（NULL 安全地變成 nil），再自己轉
(def sig-ptr (ffi/signature :default :ptr :string))
(def p (ffi/call getenv sig-ptr "HOME"))
(printf "  :ptr 回傳        => %q" p)
(printf "  沒這個變數       => %q" (ffi/call getenv sig-ptr "NO_SUCH_VAR_XYZ"))
# ★ 不能 (ffi/read :string p)——那會把 p 指的地方再當成一個 char* 解，會炸
(printf "  正解 write+read  => %q" (ffi/read :string (ffi/write :ptr p)))
# 或者知道長度，直接把那段記憶體當 buffer 看
(def n (int/to-number
         (ffi/call (ffi/lookup libc "strlen") (ffi/signature :default :size :ptr) p)))
(printf "  pointer-buffer   => %q" (string (ffi/pointer-buffer p n n 0)))

# ── 8) ffi/defbind：少寫一半樣板 ─────────────────────────────────────────
(h "ffi/context + ffi/defbind")
(ffi/context "libm.so.6")
(ffi/defbind cos :double [x :double])
(ffi/defbind pow :double [x :double y :double])
(printf "  (cos 0) => %q   (pow 2 10) => %q" (cos 0.0) (pow 2 10))

# ── 9) 找不到符號時的行為（segfault 的頭號來源）────────────────────────
(h "lookup 失敗不報錯，回 nil")
(printf "  (ffi/lookup libm \"no_such_sym\") => %q"
        (ffi/lookup (ffi/native "libm.so.6") "no_such_sym"))
(print "  → 拿 nil 去 ffi/call 才會炸，所以 lookup 完先檢查\n")
