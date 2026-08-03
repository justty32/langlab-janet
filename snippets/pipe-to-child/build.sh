#!/bin/sh
# 編出 main.janet 要餵的示範子程式。一個 .c、不需要 cmake。
# 跑法：sh snippets/pipe-to-child/build.sh
#
# 產物 child 是編譯結果，不進 git（見專案 .gitignore）。

set -eu
here=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

cc -O2 -Wall -Wextra -o "$here/child" "$here/child.c"
echo "編好了：$here/child"
echo "接著跑：janet snippets/pipe-to-child/main.janet"
