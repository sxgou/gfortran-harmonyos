/* xgcc-wrap — finds gfortran.bin (or <tool>.bin) relative to its own location.
 *
 * The gfortran (GCC driver) wrapper installed by GCC's make install is
 * an xgcc wrapper that execs the real driver binary (<name>.bin).
 *
 * The original GCC build system compiles xgcc-wrap.c with argv[0]-based
 * path resolution, which fails when the wrapper is invoked via PATH
 * (argv[0] is just "gfortran" with no directory component).
 *
 * This self-relocating version uses /proc/self/exe instead, so it works
 * regardless of how the wrapper is invoked.
 */

#define _GNU_SOURCE
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/wait.h>

#define MAX_ATTEMPTS 200

int main(int argc, char *argv[]) {
    /* Resolve self path */
    char self[4096];
    ssize_t len = readlink("/proc/self/exe", self, sizeof(self) - 1);
    if (len == -1) {
        fprintf(stderr, "xgcc-wrap: readlink /proc/self/exe failed\n");
        return 1;
    }
    self[len] = '\0';

    /* Build path to real binary: <self-path>.bin */
    char *real_path = malloc(len + 5);  /* ".bin" + NUL */
    if (!real_path) {
        fprintf(stderr, "xgcc-wrap: malloc failed\n");
        return 1;
    }
    memcpy(real_path, self, len);
    memcpy(real_path + len, ".bin", 4);
    real_path[len + 4] = '\0';

    if (access(real_path, X_OK) != 0) {
        fprintf(stderr, "xgcc-wrap: %s not found or not executable\n", real_path);
        free(real_path);
        return 1;
    }

    for (int attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
        pid_t pid = fork();
        if (pid == 0) {
            for (int i = 0; i < MAX_ATTEMPTS; i++) {
                execv(real_path, argv);
                if (errno == EINTR) {
                    usleep(100000);
                    continue;
                }
                _exit(127);
            }
            _exit(127);
        }
        if (pid < 0) {
            usleep(100000);
            continue;
        }
        int status = 0;
        pid_t wret;
        do {
            wret = waitpid(pid, &status, 0);
        } while (wret == -1 && errno == EINTR);
        if (wret == -1) {
            usleep(200000);
            continue;
        }
        if (WIFEXITED(status)) {
            int code = WEXITSTATUS(status);
            if (code == 0) return 0;
            if (code != 127) return code;
        }
        if (WIFSIGNALED(status)) {
            usleep(200000);
            continue;
        }
    }
    return 1;
}
