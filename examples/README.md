# examples · 可跑的範例

**教學的附件**——配合 `docs/` 某一篇把觀念跑一遍。想找「我要做 X，抄哪段」請看
[`snippets/`](../snippets/README.md)。每支都獨立、都實測過。

| 檔 | 主題 | 跑法 |
|----|------|------|
| `peg-demo.janet` | PEG：組合子、捕獲、具名文法、遞迴、CSV 切割 | `janet examples/peg-demo.janet` |
| `ffi-demo.janet` | C FFI（不編譯，直呼共享庫） | `janet examples/ffi-demo.janet` |
| `ffi-pointers.janet` | FFI 進階：型別大小 / struct / out 參數 / malloc / `char*` | `janet examples/ffi-pointers.janet` |
| `env-introspect.janet` | 列出 env 裡的綁定、查 symbol 型別、切換 env、OS 環境變數 | `janet examples/env-introspect.janet` |
| `subcommands.janet` | git 風格子命令 dispatcher | `janet examples/subcommands.janet add https://x.git -n libs` |
| `fibers.janet` | fiber / generator / 錯誤處理 / ev | `janet examples/fibers.janet` |
| `pipeline.janet` | 子行程 / 管線 / 信號 | `janet examples/pipeline.janet` |
| `native-module/` | 用 C 寫 Janet 原生模組 | `cd examples/native-module && jpm build`（見下） |
| `embed/` | 把 Janet 嵌進 C 程式 | `cd examples/embed`（見下） |

## native-module

```sh
cd examples/native-module
jpm build                       # 編出 build/greet.so
JANET_PATH=$PWD/build janet -e '(import greet) (print (greet/add 3 4) (greet/hello "Janet"))'
```

## embed

```sh
cd examples/embed
cc embed.c -I$HOME/.local/include/janet $HOME/.local/lib/libjanet.a \
   -lm -ldl -lpthread -lrt -rdynamic -o embed
./embed
```

對應教學：FFI / native / embed 都在 [docs/10-c-互通.md](../docs/10-c-互通.md)，
fiber 在 [docs/09-fiber.md](../docs/09-fiber.md)，子命令在 [docs/04-cli-argparse.md](../docs/04-cli-argparse.md)，
env 在 [docs/12-env-環境與動態變數.md](../docs/12-env-環境與動態變數.md)，
PEG 在 [docs/14-peg.md](../docs/14-peg.md)。
