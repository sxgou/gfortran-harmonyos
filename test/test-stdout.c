#include <stdio.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
int main() {
    fprintf(stdout, "test stdout fprintf\n");
    int r = write(1, "test stdout write\n", 18);
    fprintf(stderr, "write returned %d, errno=%d (%s)\n", r, errno, strerror(errno));
    return 0;
}
