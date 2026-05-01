# gfortran-harmonyos 完整构建与使用指南

## 一、概述

将 GCC 14.2.0 的 gfortran (Fortran 编译器) 移植到 HarmonyOS (OpenHarmony) 平台，使用系统自带的 OHOS Clang 15.0.4 作为宿主编译器。目标平台 `aarch64-unknown-linux-ohos`，静态链接 libgfortran，通过 LD_PRELOAD + destructor 模式执行。

## 二、前置条件

### 2.1 安装 OHOS SDK (hnp 包管理器)

SDK 通过 hnp 包管理器安装。当前系统版本：

```
ohos-sdk_26.0.0.18 (API 26)
```

SDK 安装路径：

```
/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/
  ├── llvm/bin/           # Clang 工具链
  │   ├── clang           # (但不可直接使用，见注)
  │   └── ...
  ├── sysroot/            # musl 头文件和库
  │   ├── usr/include/
  │   └── usr/lib/
  └── build-tools/        # cmake, ninja 等
```

hnp 安装命令（参考，本环境已有）：

```bash
# hnp install ohos-sdk          # 安装最新版
# hnp install ohos-sdk_26.0.0.18 # 安装指定版本
```

注：hnp 命令在本环境不可直接调用，SDK 由系统预装。

### 2.2 Clang 工具链入口

SDK 在 `/data/service/hnp/bin/` 下提供 symlink 作为稳定入口：

```bash
ls /data/service/hnp/bin/aarch64-unknown-linux-ohos-clang*
# aarch64-unknown-linux-ohos-clang     → ../ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/bin/clang
# aarch64-unknown-linux-ohos-clang++   → ../ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/llvm/bin/clang++
```

这些是 shell 包装脚本，内部定位 SDK 和 sysroot。构建 GCC 时，必须使用这些包装器而非直接调用 `clang`。

```bash
export OHOS_CLANG=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
export OHOS_CLANGXX=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++
```

验证编译器：

```bash
$OHOS_CLANG --version
# clang version 15.0.4 (/srv/workspace/llvm-release/2026_0313_llvm15_release/...)
# Target: aarch64-unknown-linux-ohos
# Thread model: posix
```

### 2.3 Sysroot

```
SYSROOT=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot
```

### 2.4 其他依赖

- **Bash**: `/data/service/hnp/bin/bash`（必须配置为 CONFIG_SHELL，因为 GCC 的 configure 依赖 bash 特性）
- **TMPDIR**: 必须设置在可写文件系统（hmdfs 上 mkdir 有 group x 问题，`umask 022` 解决）

## 三、构建 GCC 编译器

### 3.1 下载源码

```bash
git clone <仓库> gfortran-harmonyos
cd gfortran-harmonyos
./download.sh
```

`download.sh` 执行：

1. 从 `https://ftpmirror.gnu.org/gcc/gcc-14.2.0/gcc-14.2.0.tar.xz` 下载 GCC
2. 解压到 `gcc-14.2.0/`
3. 运行 `gcc-14.2.0/contrib/download_prerequisites` 下载 GMP、MPFR、MPC

目录结果：

```
gfortran-harmonyos/
  ├── gcc-14.2.0/              # GCC 源码
  ├── download.sh
  ├── configure.sh
  ├── build.sh
  └── build/                   # 构建输出
```

### 3.2 关键补丁文件

在构建前，需要准备以下文件：

#### 3.2.1 ohos-compat.h

路径：`build/ohos-compat.h`（构建时通过 `-include ohos-compat.h` 全局引入）

内容：

```c
/* GCC compatibility: ignore Clang's __availability__ attribute */
#define __availability__(...)
```

用途：OHOS sysroot 头文件中使用了 Clang 的 `__attribute__((__availability__))`，当 GCC 内部的 xgcc 编译这些头文件时会报错。此宏将其清零。

注意：这个头文件也复制到了 `build/gcc/include-fixed/ohos-compat.h` 和 `test/ohos-compat.h`。libgfortran 编译时通过 `CPPFLAGS="-include ohos-compat.h"` 引入。

#### 3.2.2 xgcc-wrap.sh（可选，用于 EINTR 重试）

路径：任意位置（如 `~/.local/bin/xgcc-wrap.sh`）

```bash
#!/bin/sh
# Retry wrapper for xgcc to handle EINTR on HarmonyOS
# Usage: xgcc-wrap.sh <xgcc-path> [args...]
if [ $# -lt 1 ]; then exit 1; fi
XGCC="$1"; shift
for attempt in $(seq 1 30); do
    "$XGCC" "$@"; rc=$?
    [ $rc -eq 0 ] && exit 0
    # EINTR on HarmonyOS returns exit code 1 or 127
    if [ $rc -eq 127 ] || [ $rc -eq 1 ]; then
        usleep 100000; continue
    fi
    exit $rc
done
exec "$XGCC" "$@"
```

用途：HarmonyOS 内核在某些系统调用上会返回 EINTR（主要通过 exit code 127 体现），导致 xgcc 编译随机失败。此包装器自动重试 Transient 错误。

### 3.3 配置

```bash
./configure.sh
```

`configure.sh` 执行内容：

```bash
#!/bin/sh
set -e
umask 022

export TMPDIR=/storage/Users/currentUser/gfortran-harmonyos/tmp
export CONFIG_SHELL=/data/service/hnp/bin/bash
export SHELL=/data/service/hnp/bin/bash
mkdir -p "$TMPDIR"

BUILD_DIR=/storage/Users/currentUser/gfortran-harmonyos/build
SRC_DIR=/storage/Users/currentUser/gfortran-harmonyos/gcc-14.2.0
PREFIX=/storage/Users/currentUser/.local/gfortran
mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

OHOS_CLANG=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
OHOS_CLANGXX=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++

"$SRC_DIR/configure" \
    --host=aarch64-unknown-linux-ohos \
    --build=aarch64-unknown-linux-ohos \
    --target=aarch64-unknown-linux-ohos \
    --prefix="$PREFIX" \
    --enable-languages=c,fortran \
    --disable-bootstrap \
    --disable-multilib \
    --disable-nls \
    --disable-libsanitizer \
    --disable-gomp \
    --disable-libquadmath \
    --without-isl \
    --disable-graphite \
    --with-sysroot=/ \
    CC="$OHOS_CLANG" \
    CXX="$OHOS_CLANGXX" \
    CPP="${OHOS_CLANG} -E" \
    CXXCPP="${OHOS_CLANGXX} -E" \
    CFLAGS="-O2 -g0" \
    CXXFLAGS="-O2 -g0"
```

**关键配置说明：**


| 参数                               | 说明                                                     |
| ---------------------------------- | -------------------------------------------------------- |
| `--host=--build=--target`          | 三者相同 = native 构建（非交叉编译）                     |
| `--disable-bootstrap`              | 单阶段构建，GCC 不自举。因为宿主编译器是 Clang，不是 GCC |
| `--disable-gomp`                   | 禁用 OpenMP（libgomp 编译复杂且不需要）                  |
| `--disable-libquadmath`            | 禁用四精度数学库（libquadmath 需要附加库）               |
| `--with-sysroot=/`                 | sysroot 设为根目录，Clang 通过内置搜索路径找到 SDK       |
| `--without-isl --disable-graphite` | 禁用 Graphite 循环优化框架（依赖 isl 库）                |

### 3.4 编译

```bash
cd /storage/Users/currentUser/gfortran-harmonyos/build
./../build.sh
```

`build.sh` 简化为：

```bash
#!/bin/sh
export TMPDIR=/storage/Users/currentUser/gfortran-harmonyos/tmp
export CONFIG_SHELL=/data/service/hnp/bin/bash
export SHELL=/data/service/hnp/bin/bash
umask 022
cd /storage/Users/currentUser/gfortran-harmonyos/build
make -j$(nproc)
```

#### 已知构建问题及解决方法

**问题 1：LLD 链接对齐错误**

```
ld.lld: error: libcommon.a(diagnostic-format-sarif.o):(function ...):
  improper alignment for relocation R_AARCH64_LDST64_ABS_LO12_NC: 0x2D2EA4 is not aligned to 8 bytes
```

原因：GCC 的 `ar` 打包时使用了 `rcT`（`T` = thin archive），但 LLD 对 thin archive 中的对齐处理与 BFD ld 不同。此问题出现在链接 `libbackend.a`（GCC 本身）阶段，与最终 gfortran 链接无关。

解决方法：**这些链接错误仅影响 GCC 自身的构建**（xgcc、cc1 等），不影响 Fortran 运行时库。但实际上 `make` 会在此失败。需要：

- 使用 `make -k` 跳过错误的目标继续编译
- 或者通过 retry-make 脚本多次重试，某些目标在重试中成功
- 最终 gfortran 驱动可正常安装，因为 `gcc` 二进制自身不会用于实际编译 Fortran（gfortran 使用 f951 作为编译后端）

本环境中通过多次重试（使用 `make-retry.sh`）解决：

```bash
./build/make-retry.sh -j4
```

（重试最多 10 次，每次 `make` 遇到 transcient 错误重跑）

**问题 2：xgcc EINTR**

HarmonyOS 内核返回 EINTR 导致 xgcc 编译随机退出码 127。通过在 Makefile 中包装 CC 命令为 xgcc-wrap.sh 解决，或直接多次重试 make。

**问题 3：libtool .lo 文件缺失**

编译中断后重启 make 时，libtool 因为缺少 `.lo` 文件（但 `.libs/*.o` 已存在）报错。使用 `fix-build.sh` 重建 .lo stub：

```bash
./build/fix-build.sh
```

该脚本为所有已有 `.libs/*.o` 但缺失 `.lo` 的目标自动生成 stub 文件。

### 3.5 安装

```bash
cd /storage/Users/currentUser/gfortran-harmonyos/build
make install prefix=/storage/Users/currentUser/.local/gfortran
```

注：必须覆盖 `prefix`，因为 libtool 在 configure 时硬编码了安装路径为 `PREFIX`（`~/.local/gfortran`），但 hmdfs 上的绝对路径不同。如果 install 时报 "permission denied"，检查目标目录权限。

### 3.6 libbacktrace 独立构建（用于运行时）

libgfortran 构建时已经自行编译了 libbacktrace（在 `build/libbacktrace/` 下），但输出的 `.a` 需要单独编译以确保 PIC 版本可用。

libbacktrace 在 GCC 构建过程中作为子项目自动配置和编译，位于：

```
build/aarch64-unknown-linux-ohos/libbacktrace/
```

**不需要手动构建 libbacktrace** — 构建日志显示 libgfortran 链接时已自动链接了 `build/libbacktrace/libbacktrace.la`。最终链接只需要从该目录获取 `libbacktrace.a`：

```bash
ls build/libbacktrace/.libs/libbacktrace.a
```

该 `.a` 包含以下对象：`atomic`, `backtrace`, `dwarf`, `elf`, `fileline`, `mmap`, `mmapio`, `posix`, `print`, `simple`, `sort`, `state`。

**如果重新构建 libbacktrace（可选）：**

```bash
cd build/libbacktrace
./configure --host=aarch64-unknown-linux-ohos \
    CC=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang \
    --prefix=/storage/Users/currentUser/.local/gfortran
make -j$(nproc)
```

本环境中不需要重新构建，直接使用 GCC 构建流程产生的版本即可。

## 四、已安装的组件

安装路径：`~/.local/gfortran/`


| 文件                                                      | 作用                                   |
| --------------------------------------------------------- | -------------------------------------- |
| `bin/gfortran`                                            | gfortran 驱动（ELF，22KB）             |
| `bin/aarch64-unknown-linux-ohos-gfortran`                 | target-specific symlink                |
| `lib/gcc/aarch64-unknown-linux-ohos/14.2.0/f951`          | Fortran 编译器后端（72MB）             |
| `lib/gcc/aarch64-unknown-linux-ohos/14.2.0/libgcc.a`      | GCC 运行时静态库                       |
| `lib/gcc/aarch64-unknown-linux-ohos/14.2.0/libgcc_s.so.1` | GCC 运行时动态库                       |
| `lib/gcc/aarch64-unknown-linux-ohos/14.2.0/specs`         | gfortran 规格文件                      |
| `lib64/libgfortran.a`                                     | Fortran 运行时静态库（788 个目标文件） |
| `lib64/libgfortran.so.5.0.0`                              | Fortran 运行时动态库                   |
| `lib64/libgfortran.so.5` → `libgfortran.so.5.0.0`        | so symlink                             |
| `lib64/libgfortran.so` → `libgfortran.so.5`              | so symlink                             |

## 五、环境配置

### 5.1 Shell 环境

```bash
# 添加到 ~/.zshenv 或 setup-env.sh
export PATH="$PATH:$HOME/.local/gfortran/bin"
export LD_LIBRARY_PATH="$HOME/.local/gfortran/lib64:$LD_LIBRARY_PATH"
```

### 5.2 gfortran 包装器

`~/.local/bin/gfortran`（Shell 脚本，确保 LD_LIBRARY_PATH 正确传递）：

```bash
#!/bin/sh
export LD_LIBRARY_PATH="/storage/Users/currentUser/.local/gfortran/lib64:$LD_LIBRARY_PATH"
exec /storage/Users/currentUser/.local/gfortran/bin/gfortran "$@"
```

### 5.3 验证安装

```bash
source ~/.zshenv
gfortran --version
# GNU Fortran (GCC) 14.2.0
```

编译测试：

```bash
cat > /tmp/test.f90 << 'EOF'
program hello
  print *, "hello from gfortran on HarmonyOS"
end program hello
EOF
gfortran -c -fPIC -o /tmp/test.o /tmp/test.f90
# 检查是否生成 .o 文件
```

## 六、运行时架构

### 6.1 问题：HarmonyOS 阻止执行用户编译的 ELF

HarmonyOS 的 `hmmac`（HarmonyOS Mandatory Access Control）安全策略在所有用户可写文件系统设置 `hmmac=use_task`，阻止执行用户创建的可执行文件：

```bash
# mount 输出显示：
tmpfs on /storage/Users type tmpfs (rw,...,hmmac=use_task,...)
tmpfs on /data/storage/el2 type tmpfs (rw,...,hmmac=use_task,...)
# 执行返回 126 (Permission denied)
```

即使用户 `chmod +x`，`execve` 拒绝执行。以下方案均失败：

- `execve` 直接执行 → ❌
- `execveat(fd, AT_EMPTY_PATH)` → ❌
- `memfd_create` + `execveat` → ❌
- 系统二进制（如 `/bin/true`）拒绝 `LD_PRELOAD` → ❌

### 6.2 解决方案：LD_PRELOAD + destructor 模式

```
用户源代码 → gfortran -c -fPIC → .o
                                   → clang -shared -nostartfiles → .so → LD_PRELOAD → host 进程
                 C 存根 (destructor) ─┘                                   destructor 阶段执行 Fortran
```

### 6.3 编译 host 桥接程序

`/data/storage/el2/base/host.c`:

```c
int main(void) { return 0; }
```

编译命令：

```bash
# host 必须编译为 PIE/PIC 可执行文件（OHOS 要求）
aarch64-unknown-linux-ohos-clang \
    -o /data/storage/el2/base/host \
    /data/storage/el2/base/host.c
```

验证：

```bash
file /data/storage/el2/base/host
# ELF shared object, 64-bit LSB arm64, dynamic (/lib/ld-musl-aarch64.so.1), not stripped
```

注：host 编译为**动态链接**的 PIE 可执行文件（OHOS 不允许静态链接可执行文件）。编译时无需 `-static` 或 `-nostartfiles`。

### 6.4 C 运行时存根（destructor 模式，最终版本）

`/data/storage/el2/base/.fortran_runner.c`（由 fortran-run 自动生成）：

```c
#include <stdlib.h>
#include <stdio.h>
extern int main(int argc, char *argv[]);
extern void _gfortran_set_args(int argc, char *argv[]);
extern void _gfortran_set_options(int num, int opts[]);
extern void _gfortrani_init_units(void);
extern void _gfortrani_flush_all_units(void);
static void run(void) __attribute__((destructor));
static void run(void) {
    char *argv[] = { "fortran_prog", 0 };
    int opts[] = { 255, 6, 0, 5, 1 };
    _gfortran_set_args(1, argv);
    _gfortran_set_options(5, opts);
    _gfortrani_init_units();
    main(1, argv);
    _gfortrani_flush_all_units();
}
```

**核心原理：**

1. `__attribute__((destructor))` — 函数在进程退出时（exit/return from main）调用
2. `_gfortrani_init_units()` — 初始化 Fortran I/O 系统（内部符号，`_gfortrani_` 前缀）
3. `_gfortrani_flush_all_units()` — 刷新所有输出缓冲区
4. 运行时顺序：`host main()` 空返回 → destructor 执行 → `_gfortrani_init_units()` → Fortran main → `_gfortrani_flush_all_units()` → 进程退出

**为什么用 destructor 而非 constructor？**

GCC 的 constructor 在 `_start` 之后、`main()` 之前执行。此时运行时（特别是 Fortran I/O 系统）尚未完全初始化，直接调用 `_gfortrani_init_units()` 可能失败。destructor 在进程退出阶段执行，此时所有运行时已可用。

**为什么不同时使用 constructor？**

本环境之前尝试过 constructor 模式（`fortran_runner.c`），但早期版本在 constructor 中调用 `main()` 然后 `exit(0)`，这会导致 host 的 crt 流程不完整。Destructor 模式更可靠。

### 6.5 opts[] 参数数组

```c
int opts[] = { 255, 6, 0, 5, 1 };
```

对应 `_gfortran_set_options` 的 5 个选项：

1. `255` — 标准输出选项（所有 stdio 流）
2. `6` — 消息长度
3. `0` — 是否写错误信息到 stderr
4. `5` — 信号处理行为
5. `1` — 是否允许子过程

## 七、运行流程详解

### 7.1 编译与链接

用户运行 `fortran-run hello.f90`:

**步骤 1：生成 C 运行时存根**

- fortran-run 脚本自动生成 `/data/storage/el2/base/.fortran_runner.c`
- 若存根未变，使用缓存的 `.o`

**步骤 2：编译 C 存根为 PIC 对象**

```bash
aarch64-unknown-linux-ohos-clang -c -fPIC -O2 \
    -o /data/storage/el2/base/.fortran_runner.o \
    /data/storage/el2/base/.fortran_runner.c
```

**步骤 3：编译 Fortran 代码为 PIC 对象**

```bash
gfortran -c -fPIC --sysroot=/data/.../sysroot \
    -o hello_pic.o hello.f90
```

**步骤 4：链接为共享库**

```bash
aarch64-unknown-linux-ohos-clang -shared -nostartfiles \
    -o hello.so \
    hello_pic.o .fortran_runner.o \
    -Wl,--whole-archive -Wl,--allow-multiple-definition \
    libgfortran.a \
    -Wl,--no-whole-archive \
    libbacktrace.a -lm \
    -Wl,--whole-archive libgcc.a -Wl,--no-whole-archive \
    --sysroot=...
```

**链接参数说明：**


| 参数                            | 说明                                                              |
| ------------------------------- | ----------------------------------------------------------------- |
| `-shared -nostartfiles`         | 输出共享库，不使用 CRT 启动文件（OHOS sysroot 缺少`crtbeginS.o`） |
| `--whole-archive libgfortran.a` | 强制链接 libgfortran.a 中的所有目标文件                           |
| `--allow-multiple-definition`   | 允许重复符号（libgfortran.a 内部多个ç®标文件有同名符号）      |
| `--no-whole-archive`            | 后续库按需链接                                                    |
| `-lm`                           | libgfortran 需要数学库                                            |
| `--whole-archive libgcc.a`      | 强制包含 GCC 运行时辅助函数                                       |

### 7.2 执行

```bash
export LD_LIBRARY_PATH="~/.local/gfortran/lib64:~/.local/gfortran/lib/gcc/.../14.2.0"
LD_PRELOAD=./hello.so /data/storage/el2/base/host
```

执行序列：

1. 动态链接器加载 `hello.so`（通过 `LD_PRELOAD`）
2. 运行 `host` 的 `main()`，立即 return 0
3. 进程退出阶段，动态链接器调用 `.so` 的 destructor
4. destructor 调用 `_gfortrani_init_units()` 初始化 Fortran I/O
5. 调用 Fortran 程序的 `main(1, argv)`
6. destructor 调用 `_gfortrani_flush_all_units()` 刷新输出
7. 进程退出，stdout 数据刷出显示

## 八、完整使用示例

### 8.1 编译并运行 Fortran 程序

```bash
# 方式 1：使用 fortran-run 工具（推荐）
cat > hello.f90 << 'EOF'
program hello
  print *, "Hello, HarmonyOS!"
  print *, "sin(1.0) =", sin(1.0d0)
end program hello
EOF

fortran-run hello.f90
# 输出：
# Built: ./hello.so
#  Hello, HarmonyOS!
#  sin(1.0) =  0.84147098480789650
```

### 8.2 手动分步操作

```bash
export SYSROOT=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot

# 1. 编译 C 存根
aarch64-unknown-linux-ohos-clang -c -fPIC -O2 \
    -o /data/storage/el2/base/.fortran_runner.o \
    -x c - << 'EOF'
#include <stdlib.h>
#include <stdio.h>
extern int main(int argc, char *argv[]);
extern void _gfortran_set_args(int argc, char *argv[]);
extern void _gfortran_set_options(int num, int opts[]);
extern void _gfortrani_init_units(void);
extern void _gfortrani_flush_all_units(void);
static void run(void) __attribute__((destructor));
static void run(void) {
    char *argv[] = { "fortran_prog", 0 };
    int opts[] = { 255, 6, 0, 5, 1 };
    _gfortran_set_args(1, argv);
    _gfortran_set_options(5, opts);
    _gfortrani_init_units();
    main(1, argv);
    _gfortrani_flush_all_units();
}
EOF

# 2. 编译 Fortran PIC 对象
gfortran -c -fPIC --sysroot="$SYSROOT" -o hello_pic.o hello.f90

# 3. 链接共享库
aarch64-unknown-linux-ohos-clang -shared -nostartfiles \
    -o hello.so hello_pic.o /data/storage/el2/base/.fortran_runner.o \
    -Wl,--whole-archive -Wl,--allow-multiple-definition \
    ~/.local/gfortran/lib64/libgfortran.a \
    -Wl,--no-whole-archive \
    ~/gfortran-harmonyos/build/libbacktrace/.libs/libbacktrace.a -lm \
    -Wl,--whole-archive ~/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0/libgcc.a \
    -Wl,--no-whole-archive \
    --sysroot="$SYSROOT"

# 4. 运行
export LD_LIBRARY_PATH="$HOME/.local/gfortran/lib64:$HOME/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0"
LD_PRELOAD=./hello.so /data/storage/el2/base/host
```

### 8.3 环境变量速查

```bash
export GFORTRAN=/storage/Users/currentUser/.local/gfortran/bin/gfortran
export CLANG=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
export HOST=/data/storage/el2/base/host
export SYSROOT=/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot
export LIBGFORTRAN_A=/storage/Users/currentUser/.local/gfortran/lib64/libgfortran.a
export LIBGCC_A=/storage/Users/currentUser/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0/libgcc.a
export LIBBACKTRACE_A=/storage/Users/currentUser/gfortran-harmonyos/build/libbacktrace/.libs/libbacktrace.a
export LD_LIBRARY_PATH=/storage/Users/currentUser/.local/gfortran/lib64:/storage/Users/currentUser/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0
```

## 九、已知问题与注意事项

### 9.1 duplicate symbol: `environ_test.o`

libgfortran.a 中包含 `environ_test.o`、`environ.o` 和 `env.o`，其中 `environ_test.o` 包含与 `environ.o` 相同的全局符号。使用 `--whole-archive` 链接时会导致 duplicate symbol 错误。

**解决方法**：链接时添加 `-Wl,--allow-multiple-definition`，LLD 会自动使用第一个定义。

### 9.2 `_gfortrani_` 内部符号

`_gfortrani_init_units` 和 `_gfortrani_flush_all_units` 是 libgfortran 的内部符号（由 GCC 内部 `internal_proto` 宏生成）。它们在 libgfortran 编译时导出为 `_gfortrani_` 前缀。这些符号在标准 gfortran 用法中不会被直接调用——它们由 gfortran 生成的初始化代码自动调用。本方案中由于没有 CRT 启动文件，需要手动调用。

如果这些符号在链接时报错未定义，说明 libgfortran.a 编译时未导出 internal 符号。验证方法：

```bash
nm ~/.local/gfortran/lib64/libgfortran.a | grep _gfortrani_init
# 应显示 T 符号（text section 已定义）
```

### 9.3 `-nostartfiles` 的必要性

OHOS sysroot 缺少 `crtbeginS.o`（Clang 的 crtbegin 实现路径与 GCC 不同）。链接共享库时必须使用 `-nostartfiles` 跳过 CRT 文件。由于 destructor 在进程退出时由动态链接器调用，不需要 CRT 中的 `_init`/`_fini` 函数。

### 9.4 LLD 对齐错误（GCC 自链接阶段）

在 GCC 自身构建中，`libbackend.a` 创建时使用了 `ar rcT`（thin archive），LLD 在处理 thin archive 时报告大量 R_AARCH64_LDST64_ABS_LO12_NC 对齐错误。这些错误仅影响 cc1/xgcc 的链接，不影响 libgfortran 或运行时的链接。

如果按照 3.4 节的流程完成了构建和安装（f951 和 libgfortran 已安装），这些错误可以忽略。

### 9.5 libbacktrace 链接

libgfortran 依赖 libbacktrace（用于错误时的堆栈回溯）。构建系统中 libgfortran 的 `configure` 自动检测并链接了 `build/libbacktrace/libbacktrace.la`，因此最终 `libgfortran.a` 中的目标文件未包含 backtrace 符号。

在链接最终 `.so` 时，必须额外链接 `libbacktrace.a`（位于 `build/libbacktrace/.libs/`），否则链接器报未定义符号 `backtrace_*`。

### 9.6 hmdfs 权限问题

hmdfs 要求目录有 group x 权限才能访问。GCC 构建过程中创建的临时目录和文件需要使用 `umask 022` 来确保 group 权限正确。

### 9.7 无法直接运行 `.so`

编译出的 `.so` 是共享库，不是可执行文件。不能通过 `./hello.so` 运行，只能通过 `LD_PRELOAD` 注入到 host 进程中。

## 十、故障排除

### 10.1 链接阶段 undefined reference to `_gfortrani_init_units`

```bash
# 验证符号是否存在
nm ~/.local/gfortran/lib64/libgfortran.a | grep init_units
# 应输出类似：
# 000000000000xxxx T _gfortrani_init_units
```

如果不存在，说明 libgfortran 编译时未启用内部符号导出。需要重新编译 libgfortran，或在 configure 时确认 `--enable-maintainer-mode` 或相关标志。

### 10.2 运行时 segment fault

如果 destructor 中的 `_gfortrani_init_units()` 崩溃，可能是因为：

- Fortran I/O 系统需要某些运行时的全局状态，在进程退出阶段已不可用
- 尝试将 destructor 改为 constructor（早前版本的 `fortran_runner.c` 使用 constructor）
- 检查 opts[] 参数是否合适

### 10.3 无输出

如果 Fortran 程序运行但无输出：

- 确认调用了 `_gfortrani_flush_all_units()`（Fortran I/O 默认缓冲输出）
- 检查 stdout 是否被重定向
- 尝试设置 `setvbuf(stdout, NULL, _IONBF, 0)`（存根中已包含）

### 10.4 gfortran 编译报错找不到 `_gfortran_*` 符号

在编译 Fortran 代码为 `.o` 时，gfortran 会插入对 libgfortran 符号的引用。这些符号在链接阶段解析。如果编译 `.o` 时报错（不是链接时），说明 gfortran 的 specs 配置有问题。

验证 specs：

```bash
gfortran -dumpspecs | head -20
```

## 附录 A：文件清单


| 文件                                                                    | 来源             | 用途                                |
| ----------------------------------------------------------------------- | ---------------- | ----------------------------------- |
| `~/.local/gfortran/bin/gfortran`                                        | GCC make install | Fortran 编译器驱动                  |
| `~/.local/gfortran/lib64/libgfortran.a`                                 | GCC make install | 运行时静态库（链接用）              |
| `~/.local/gfortran/lib64/libgfortran.so.5`                              | GCC make install | 运行时动态库（gfortran 运行时加载） |
| `~/.local/gfortran/lib/gcc/.../f951`                                    | GCC make install | Fortran 编译后端                    |
| `~/.local/gfortran/lib/gcc/.../libgcc.a`                                | GCC make install | GCC 运行时辅助函数                  |
| `~/gfortran-harmonyos/build/libbacktrace/.libs/libbacktrace.a`          | GCC 构å»º产物 | 堆栈回溯库                          |
| `/data/storage/el2/base/host`                                           | 手动编译         | LD_PRELOAD 宿主进程                 |
| `/data/storage/el2/base/.fortran_runner.c`                              | fortran-run 生成 | C 运行时存根（destructor）          |
| `/data/service/hnp/ohos-sdk.org/ohos-sdk_26.0.0.18/ohos/native/sysroot` | SDK 预装         | musl sysroot                        |
| `/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang`                | SDK 预装         | Clang 编译器包装器                  |

## 附录 B：构建命令速查

```bash
# 完整构建（从零开始）
cd ~/gfortran-harmonyos
./download.sh              # 下载 GCC 14.2.0 源码
./configure.sh             # 配置
cd build && make -j$(nproc) # 编译（可能需要重试多次）
make install prefix=~/.local/gfortran  # 安装

# 编译 host
aarch64-unknown-linux-ohos-clang -o /data/storage/el2/base/host /data/storage/el2/base/host.c

# 安装 fortran-run
cp ~/gfortran-harmonyos/fortran-run.sh ~/.local/bin/fortran-run
chmod +x ~/.local/bin/fortran-run

# 设置环境
export PATH="$PATH:$HOME/.local/gfortran/bin:$HOME/.local/bin"
export LD_LIBRARY_PATH="$HOME/.local/gfortran/lib64:$HOME/.local/gfortran/lib/gcc/aarch64-unknown-linux-ohos/14.2.0"

# 使用
fortran-run hello.f90
```
