#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/wait.h>

int main(int argc, char *argv[]) {
    /* Look for "-o -" or "-" as the input or output file */
    int use_stdout = 0;
    int i;
    char tmpfile[] = "/storage/Users/currentUser/tmp_cc1_XXXXXX";
    char **args = malloc((argc + 3) * sizeof(char *));
    int n = 0;
    
    args[n++] = "/storage/Users/currentUser/gfortran-harmonyos/build/gcc/cc1.real";
    
    for (i = 1; i < argc; i++) {
        /* If output goes to stdout, redirect to temp file */
        if (strcmp(argv[i], "-") == 0 && 
            (i == 0 || (strcmp(argv[i-1], "-o") != 0 && strcmp(argv[i-1], "-fbridge-export") != 0))) {
            /* "-" as input file is stdin - pass through */
            args[n++] = argv[i];
        } else if (i > 0 && strcmp(argv[i-1], "-o") == 0 && strcmp(argv[i], "-") == 0) {
            /* "-o -" → redirect to temp file */
            use_stdout = 1;
            int fd = mkstemp(tmpfile);
            if (fd == -1) { perror("mkstemp"); return 1; }
            close(fd);
            args[n] = malloc(strlen(tmpfile) + 1);
            strcpy(args[n], tmpfile);
            n++;
        } else if (strcmp(argv[i], "-o") == 0 && i+1 < argc && strcmp(argv[i+1], "-") == 0) {
            /* Skip "-o" here, handle in next iteration */
            i++;
            use_stdout = 1;
            int fd = mkstemp(tmpfile);
            if (fd == -1) { perror("mkstemp"); return 1; }
            close(fd);
            args[n] = malloc(strlen(tmpfile) + 1);
            strcpy(args[n], tmpfile);
            n++;
        } else {
            args[n++] = argv[i];
        }
    }
    args[n] = NULL;
    
    pid_t pid = fork();
    if (pid == 0) {
        execv(args[0], args);
        _exit(127);
    }
    
    int status;
    waitpid(pid, &status, 0);
    
    if (use_stdout && WIFEXITED(status) && WEXITSTATUS(status) == 0) {
        /* Output the temp file to stdout */
        FILE *f = fopen(tmpfile, "r");
        if (f) {
            char buf[8192];
            size_t len;
            while ((len = fread(buf, 1, sizeof(buf), f)) > 0)
                fwrite(buf, 1, len, stdout);
            fclose(f);
        }
        unlink(tmpfile);
    }
    
    if (WIFEXITED(status))
        return WEXITSTATUS(status);
    return 1;
}
