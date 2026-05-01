# gfortran-harmonyos

Build gfortran (Fortran compiler) for HarmonyOS using the system's OHOS Clang.

## Approach

Since HarmonyOS lacks GCC and the standard Fortran frontend (flang from LLVM) is not
available for OHOS Clang 15, we build gfortran from GCC 14 source using:

- **Host compiler**: OHOS Clang 15.0.4 (`aarch64-unknown-linux-ohos-clang`)
- **Target**: `aarch64-unknown-linux-ohos` (native build, not cross-compilation)
- **GCC version**: 14.2.0
- **Prerequisites**: GMP, MPFR, MPC (downloaded as part of GCC build)

## Build Steps

```bash
# 1. Download GCC source
./download.sh

# 2. Configure with OHOS Clang
./configure.sh

# 3. Build (parallel, uses all cores)
cd build && make -j$(nproc)

# 4. Install to ~/.local/gfortran
# (use prefix override since libtool hardcodes the install path)
cd build && make install prefix=~/.local/gfortran
```

## Requirements

- GCC 14.2.0 source
- OHOS Clang 15.0.4+ (`aarch64-unknown-linux-ohos-clang`)
- GMP, MPFR, MPC (downloaded by `download.sh`)
- GNU Bash as CONFIG_SHELL
- `ohos-compat.h` → Compatibility header needed when building with GCC's xgcc,
  which does not understand Clang's `__attribute__((__availability__))` syntax
  used in OHOS sysroot headers.

## Project Status ✅


| Component                   | Status                              |
| --------------------------- | ----------------------------------- |
| `gfortran` driver           | ✅ Built & installed                |
| `f951` (Fortran compiler)   | ✅ Built & installed (72MB backend) |
| `libgfortran.so.5`          | ✅ Built & installed                |
| `libgfortran.a` (static)    | ✅ Built & installed                |
| Hello World compilation     | ✅ Tested                           |
| Math intrinsics (sin, sqrt) | ✅ Tested                           |

## Install Path

`~/.local/gfortran/` — set up environment:

```bash
export PATH=~/.local/gfortran/bin:$PATH
export LD_LIBRARY_PATH=~/.local/gfortran/lib64:$LD_LIBRARY_PATH
```

## Known Issues

1. **hmdfs execution restriction**: Binaries compiled on hmdfs (`/storage/`)
   cannot be executed directly from that filesystem. Copy to a tmpfs or
   non-hmdfs location to run.
2. **`-include ohos-compat.h`**: Required when compiling C code with xgcc
   (the internal GCC-built C compiler) against OHOS sysroot headers, due to
   Clang-specific `__attribute__((__availability__))` syntax.

## Test

```bash
source setup-env.sh
cat > hello.f90 << 'EOF'
program hello; print *, "ok"; end program hello
EOF
gfortran -o hello hello.f90 && ./hello
```
