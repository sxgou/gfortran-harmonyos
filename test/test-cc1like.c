#include <stdio.h>
#include <errno.h>
#include <string.h>
#include <stdlib.h>
int main() {
    FILE *outf = stdout;
    fprintf(stderr, "outf=%p, stdout=%p, same=%d\n", (void*)outf, (void*)stdout, outf == stdout);
    /* Check stdout flags */
    fprintf(stderr, "stdout->_flags = %d\n", stdout->_flags);
    /* Try writing like cc1 does */
    int r = putc('X', outf);
    if (r == EOF) {
        fprintf(stderr, "putc failed: errno=%d (%s)\n", errno, strerror(errno));
    } else {
        fflush(outf);
        fprintf(stderr, "putc succeeded: wrote '%c'\n", r);
    }
    return 0;
}
