#include <unistd.h>
int main() {
    char *clang = "/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/bin/clang-15";
    char *args[] = {
        clang,
        "-c", "-x", "assembler",
        "-target", "aarch64-linux-ohos",
        "--sysroot=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot",
        "-D__MUSL__",
        "-o", "/dev/null",
        "-DL_cas", "-DSIZE=1", "-DMODEL=1",
        "/storage/Users/currentUser/gfortran-harmonyos/gcc-14.2.0/libgcc/config/aarch64/lse.S",
        NULL
    };
    execv(clang, args);
    return 1;
}
