#include <stdio.h>
int main() {
    fprintf(stderr, "stdout = %p\n", (void*)stdout);
    fprintf(stderr, "stdout align = %lu\n", (unsigned long)stdout & 7);
    fprintf(stderr, "stderr = %p\n", (void*)stderr);
    fprintf(stderr, "stdin  = %p\n", (void*)stdin);
    return 0;
}
