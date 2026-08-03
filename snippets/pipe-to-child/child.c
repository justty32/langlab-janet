/* 被餵資料的示範子程式：一行一行讀 stdin，加工後印到 stdout，
 * 收到 EOF 就印統計並結束。故意寫得像個真的 CLI 工具。
 *
 * 編：cc -O2 -o child child.c        （不需要 cmake，一個檔就夠）
 * 單獨試：printf 'a\nb\n' | ./child
 */

#include <stdio.h>
#include <string.h>
#include <time.h>

int main(void) {
    char line[4096];
    long n = 0, bytes = 0;

    /* 讓上游能立刻看到我們的輸出，不要卡在 libc 的行緩衝裡。
     * 這是寫「被管線餵資料」的程式時最常忘的一步。 */
    setvbuf(stdout, NULL, _IONBF, 0);

    fprintf(stdout, "[child] 起來了，等 stdin\n");

    while (fgets(line, sizeof line, stdin) != NULL) {
        size_t len = strlen(line);
        if (len > 0 && line[len - 1] == '\n') line[--len] = '\0';
        n++;
        bytes += (long)len;
        fprintf(stdout, "[child] 第 %ld 行：\"%s\"（%zu bytes）\n", n, line, len);
    }

    /* fgets 回 NULL = 對方關掉了 stdin（EOF） */
    fprintf(stdout, "[child] 收到 EOF，共 %ld 行 / %ld bytes，結束\n", n, bytes);
    return 0;
}
