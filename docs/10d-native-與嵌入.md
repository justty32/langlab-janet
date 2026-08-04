# 10d · native 模組與嵌入

[← 10c 字串回傳與地雷合輯](10c-ffi-字串與地雷.md)｜回到 [10 與 C 互通](10-c-互通.md)

不想用 FFI（或需要更貼近 Janet runtime）時的另外兩條路。

## 二、native 模組：用 C 寫 Janet 函式

要效能或要貼著某個 C 函式庫時，寫一個原生模組，jpm 幫你編成 `.so`，之後 `(import)` 就像純
Janet 模組一樣用。

`project.janet`：

```janet
(declare-project :name "greet")
(declare-native :name "greet" :source ["src/greet.c"])
```

`src/greet.c`（骨架）：

```c
#include <janet.h>

static Janet cfun_add(int32_t argc, Janet *argv) {
    janet_fixarity(argc, 2);                 /* 檢查參數個數 */
    double a = janet_getnumber(argv, 0);     /* 取 + 型別檢查 */
    double b = janet_getnumber(argv, 1);
    return janet_wrap_number(a + b);         /* 包回 Janet 值 */
}

static const JanetReg cfuns[] = {
    {"add", cfun_add, "(greet/add a b) 相加"},
    {NULL, NULL, NULL}
};

JANET_MODULE_ENTRY(JanetTable *env) {        /* import 時被呼叫 */
    janet_cfuns(env, "greet", cfuns);
}
```

編 + 用：

```sh
cd examples/native-module && jpm build
JANET_PATH=$PWD/build janet -e '(import greet) (print (greet/add 3 4))'   # => 7
```

核心 API 三件：`janet_get*`（取參數 + 檢查）、`janet_wrap_*`（把 C 值包成 Janet）、
`JANET_MODULE_ENTRY` + `janet_cfuns`（註冊）。完整可跑：
[`examples/native-module/`](../examples/native-module/)。

---

## 三、嵌入：把 Janet 塞進 C 程式

主程式是 C、想用 Janet 當內嵌腳本 / 設定語言：

```c
#include <janet.h>
#include <stdio.h>

int main(void) {
    janet_init();                               /* 起 runtime */
    JanetTable *env = janet_core_env(NULL);     /* 核心環境 */

    janet_dostring(env, "(print (+ 2 3))", "embed", NULL);   /* 跑一段 */

    Janet out;                                  /* 求值並取回結果 */
    janet_dostring(env, "(* 6 7)", "embed", &out);
    printf("結果 = %d\n", (int)janet_unwrap_number(out));

    janet_deinit();
    return 0;
}
```

編（把 `libjanet.a` 靜態連入，產物不需系統有 janet）：

```sh
cc embed.c -I$HOME/.local/include/janet $HOME/.local/lib/libjanet.a \
   -lm -ldl -lpthread -lrt -rdynamic -o embed
./embed
```

`libjanet.a`（靜態）和 `libjanet.so`（動態）都在 `~/.local/lib/`；header 在
`~/.local/include/janet/janet.h`。用靜態庫最省事，因為這台的 `libjanet.so` 沒進 ldconfig
cache（見 [00 環境](00-環境與工具鏈.md)）。完整可跑：[`examples/embed/`](../examples/embed/)。

---

可跑範例：[`examples/ffi-demo.janet`](../examples/ffi-demo.janet)（基本呼叫）、
[`examples/ffi-pointers.janet`](../examples/ffi-pointers.janet)（型別 / struct / out 參數 /
malloc / `char*`）。

下一步：[11-pipeline-signal.md](11-pipeline-signal.md)。
