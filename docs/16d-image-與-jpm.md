# 16d · image 與 jpm：archive 與獨立執行檔

[← 16c image 怎麼用](16c-image-怎麼用.md)｜回 [16 marshal 與自省](16-marshal-與自省.md)

jpm 有兩個宣告會做 image：`declare-archive` 產出 `.jimage` 檔，`declare-executable` 把 image
埋進 C 程式編成執行檔。兩個都建在 [16b](16b-image-存成檔.md) 那套 `make-image`／`marshal` 上，
差別在**怎麼處理 native 模組**。

## `declare-archive`：多支檔打包成一個 `.jimage`

```janet
# project.janet
(declare-project :name "arch-demo" :version "0.0.1")
(declare-archive :name "arch-demo" :entry "main.janet")
```

```janet
# main.janet
(import ./util)
(defn main [& args] (print (util/shout "archive works") " " (length args)))
# util.janet
(defn shout [s] (string/ascii-upper s))
```

```
$ jpm build
$ janet -i build/arch-demo.jimage a b
ARCHIVE WORKS 3
```

jpm 做的事只有一行：`(spit "build/<name>.jimage" (make-image (require entry)))`。
`./util` 因為被 `import`，整個 env 跟著進 image，所以 368 bytes 的檔就是完整程式。
`jpm install` 把它複製成 syspath 底下的 `arch-demo.jimage`，之後任何地方 `(import arch-demo)`
都找得到（[16c](16c-image-怎麼用.md)：`import` 本來就認 `.jimage`）；`jpm uninstall arch-demo` 拿掉。

限制跟 16b 一樣：entry 頂層 `import` 到 native 模組就 `cannot marshal <cfunction …>`。
archive 適合**純 Janet** 的工具；要 native 就用下一節。

## `declare-executable`：image 埋進 C，native 靜態連結

`jpm build` 產生的 `build/janet-lab.exe.c` 打開看，結構就是 [10d](10d-native-與嵌入.md) 的嵌入寫法：

```c
static const unsigned char bytes[] = {215, 0, 205, 0, …};   /* image */
extern void janet_module_entry_spork_47_json(JanetTable *);  /* 找到的 native */

int main(int argc, const char **argv) {
    janet_init();
    JanetTable *env = janet_core_env(NULL);
    JanetTable *lookup = janet_env_lookup(env);            /* ＝ load-image-dict */
    temptab = janet_table(0); temptab->proto = env;
    janet_module_entry_spork_47_json(temptab);             /* 把 json 的 cfunction 註冊進查找表 */
    janet_env_lookup_into(lookup, temptab, "_0000e4", 0);
    Janet marsh_out = janet_unmarshal(bytes, size, 0, lookup, NULL);
    /* …驗證是 function，用 argv 呼叫… */
}
```

跟 `janet -c` 的三個差別：

| | `janet -c`／`declare-archive` | `declare-executable` |
|---|---|---|
| 存什麼 | 整張 env | **只有 `main` 這個函式**（`(marshal main mdict)`）|
| 查找表 | core 而已 | core ＋ 每個載到的 native 模組的 cfunction，各自加一個 gensym 前綴 |
| native 怎麼跑 | 存不了 | 掃 `module/cache` 找 `:native` 的項目，把對應的 `.a` 靜態連結進去，啟動時先註冊再 unmarshal |

所以 `jpm build` 出來的執行檔**不需要 janet 也不需要 spork**，但它也因此要有 C 編譯器與
每個 native 的靜態庫（`json.a`）——Windows 上那整串坑在 [00b](00b-windows-vscode.md)。
只存 `main` 也呼應 [05b](05b-建立新專案.md) 那條「頂層程式碼比 `main` 還早跑」：
頂層的事在 build 時跑掉，執行檔裡只剩 `main` 閉包抓得到的東西。

## 什麼時候用哪個

| 情境 | 用 |
|------|----|
| 純 Janet 工具，對方機器有 janet | `declare-archive`，或直接 `janet -c` |
| 要 native 模組、或對方沒裝 janet | `declare-executable` |
| 開發期只想省 parse 時間 | 不值得；24 ms 對 35 ms（16c），而且會撞 `.jimage` 蓋過 `.janet` 的坑 |
| 存工作狀態下次接著跑 | 程式內 `make-image`，見 [`snippets/checkpoint/`](../snippets/checkpoint/main.janet) |

⚠ 三種都**綁 Janet 版本**（image 用名字對 core、用 bytecode 格式對 VM）。
執行檔把 VM 一起帶著所以沒事；`.jimage` 檔換 janet 版本就要重編，別拿它當長期格式。

---

回目錄：[主題索引](主題與-spork-索引.md)。
