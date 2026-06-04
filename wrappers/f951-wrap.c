/* f951 wrapper — finds f951.real relative to its own location.
 *
 * The compiled f951 (this binary) and f951.real (the actual compiler backend)
 * always reside in the same directory:
 *   ${prefix}/lib/gcc/aarch64-unknown-linux-ohos/14.2.0/f951
 *   ${prefix}/lib/gcc/aarch64-unknown-linux-ohos/14.2.0/f951.real
 *
 * By resolving via /proc/self/exe rather than a hardcoded build-time path,
 * this wrapper works correctly regardless of where the toolchain is installed.
 */

#define _GNU_SOURCE
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/wait.h>
#include <libgen.h>

int main(int argc, char *argv[]) {
    char self[4096];
    ssize_t len;

    len = readlink("/proc/self/exe", self, sizeof(self) - 1);
    if (len == -1) {
        fprintf(stderr, "f951-wrap: readlink /proc/self/exe failed\n");
        return 1;
    }
    self[len] = '\0';

    /* Build path to f951.real in the same directory */
    char *real_path = malloc(len + 6);  /* ".real" + NUL */
    if (!real_path) {
        fprintf(stderr, "f951-wrap: malloc failed\n");
        return 1;
    }
    memcpy(real_path, self, len);
    memcpy(real_path + len, ".real", 5);
    real_path[len + 5] = '\0';

    if (access(real_path, X_OK) != 0) {
        fprintf(stderr, "f951-wrap: %s not found or not executable\n", real_path);
        free(real_path);
        return 1;
    }

    pid_t pid = fork();
    if (pid == 0) {
        execv(real_path, argv);
        _exit(127);
    }

    int status;
    waitpid(pid, &status, 0);
    free(real_path);

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 1;
}
