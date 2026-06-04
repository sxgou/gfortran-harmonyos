/* cc1/cc1plus wrapper — finds cc1.real relative to its own location.
 *
 * Like f951-wrap.c, this wrapper resolves the real compiler backend via
 * /proc/self/exe instead of a hardcoded build-time path.
 *
 * It also handles a HarmonyOS-specific workaround: when cc1 is invoked
 * with -o - (output to stdout), LLD / the filesystem may corrupt the pipe.
 * mkstemp + stdout dump provides a reliable fallback.
 */

#define _GNU_SOURCE
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/wait.h>
#include <fcntl.h>

static int has_stdout_output(int argc, char *argv[]) {
    for (int i = 1; i < argc - 1; i++) {
        if (strcmp(argv[i], "-o") == 0 && strcmp(argv[i + 1], "-") == 0)
            return 1;
    }
    return 0;
}

int main(int argc, char *argv[]) {
    char self[4096];
    ssize_t len;

    len = readlink("/proc/self/exe", self, sizeof(self) - 1);
    if (len == -1) {
        fprintf(stderr, "cc1-wrap: readlink /proc/self/exe failed\n");
        return 1;
    }
    self[len] = '\0';

    /* Determine the real binary name.
     * This wrapper can be installed as cc1, cc1plus, or any cc1 variant.
     * The real binary is named cc1.real, cc1plus.real, etc. */
    char *real_path = malloc(len + 6);
    if (!real_path) {
        fprintf(stderr, "cc1-wrap: malloc failed\n");
        return 1;
    }
    memcpy(real_path, self, len);
    memcpy(real_path + len, ".real", 5);
    real_path[len + 5] = '\0';

    if (access(real_path, X_OK) != 0) {
        /* Fall back to cc1.real (for cc1plus -> cc1.real forwarding) */
        char *base = strrchr(self, '/');
        if (base) {
            size_t dir_len = base - self;
            free(real_path);
            real_path = malloc(dir_len + 9);  /* "/cc1.real" + NUL */
            if (!real_path) {
                fprintf(stderr, "cc1-wrap: malloc failed\n");
                return 1;
            }
            memcpy(real_path, self, dir_len);
            memcpy(real_path + dir_len, "/cc1.real", 9);
            real_path[dir_len + 9] = '\0';
        }
        if (access(real_path, X_OK) != 0) {
            fprintf(stderr, "cc1-wrap: %s not found or not executable\n", real_path);
            free(real_path);
            return 1;
        }
    }

    /* Handle -o - (stdout output) with a temp file workaround */
    char tmpout[] = "/tmp/cc1_out_XXXXXX";
    int use_stdout = 0;

    if (has_stdout_output(argc, argv)) {
        use_stdout = 1;
        int fd = mkstemp(tmpout);
        if (fd == -1) { perror("cc1-wrap: mkstemp"); return 1; }
        close(fd);
        /* Replace -o - with -o tmpfile */
        for (int i = 1; i < argc - 1; i++) {
            if (strcmp(argv[i], "-o") == 0 && strcmp(argv[i + 1], "-") == 0) {
                argv[i + 1] = tmpout;
                break;
            }
        }
    }

    pid_t pid = fork();
    if (pid == 0) {
        execv(real_path, argv);
        _exit(127);
    }

    int status;
    waitpid(pid, &status, 0);
    free(real_path);

    if (use_stdout && WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        FILE *f = fopen(tmpout, "r");
        if (f) {
            char buf[8192];
            size_t n;
            while ((n = fread(buf, 1, sizeof(buf), f)) > 0)
                fwrite(buf, 1, n, stdout);
            fclose(f);
        }
        unlink(tmpout);
    }

    if (WIFEXITED(status)) return WEXITSTATUS(status);
    return 1;
}
