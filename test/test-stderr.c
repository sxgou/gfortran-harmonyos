#include <stdio.h>
#include <errno.h>
int main() {
    FILE *f = stdout;
    int r = fputs("test\n", f);
    fprintf(stderr, "fputs returned %d, errno=%d\n", r, errno);
    return 0;
}
