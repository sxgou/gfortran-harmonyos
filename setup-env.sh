#!/bin/sh
# Setup environment for gfortran on HarmonyOS
# Source this file: . ./setup-env.sh
#
# This script:
#   1. Adds gfortran to PATH and LD_LIBRARY_PATH
#   2. Creates the aarch64-unknown-linux-ohos-as symlink if missing
#   3. Compiles relocatable f951/cc1 wrappers if missing

PREFIX="${HOME}/.local/gfortran"
GCC_LIB="${PREFIX}/lib/gcc/aarch64-unknown-linux-ohos/14.2.0"
CLANG="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"

# 1. Basic paths
export PATH="${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${PREFIX}/lib64:${GCC_LIB}:${LD_LIBRARY_PATH}"

# 2. Create aarch64-unknown-linux-ohos-as symlink if missing
AS_TARGET="${PREFIX}/bin/aarch64-unknown-linux-ohos-as"
if [ ! -x "${AS_TARGET}" ]; then
    if command -v as >/dev/null 2>&1; then
        AS_SOURCE="$(command -v as)"
        ln -sf "${AS_SOURCE}" "${AS_TARGET}"
        echo "  [setup] Created ${AS_TARGET} → ${AS_SOURCE}"
    elif [ -x /data/service/hnp/bin/as ]; then
        ln -sf /data/service/hnp/bin/as "${AS_TARGET}"
        echo "  [setup] Created ${AS_TARGET} → /data/service/hnp/bin/as"
    fi
fi

# 3. Replace f951 wrapper with relocatable version if the installed
#    wrapper has a hardcoded build path (detected by checking if the
#    wrapper tries to exec a non-existent absolute path).
WRAPPER_SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/wrappers/f951-wrap.c"
F951="${GCC_LIB}/f951"
if [ -f "$WRAPPER_SRC" ] && [ -f "$F951" ] && [ -x "$CLANG" ]; then
    # Check if f951.real is in the same directory (indicates relocation is needed)
    if [ -f "${GCC_LIB}/f951.real" ]; then
        # Test if the current wrapper still uses a hardcoded build path
        # by checking if it's the old compiled binary vs our relocatable version
        if strings "$F951" 2>/dev/null | grep -q "/build/gcc/f951.real"; then
            "${CLANG}" -O2 -g0 -o "${F951}" "${WRAPPER_SRC}"
            chmod 755 "${F951}"
            echo "  [setup] Replaced f951 wrapper with relocatable version"
        fi
    fi
fi

# 4. Replace gfortran (xgcc) driver wrapper if it uses argv[0]-based resolution
#    (detected by checking if gfortran fails when invoked via PATH)
XGCC_WRAPPER_SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/wrappers/xgcc-wrap.c"
GFORTRAN_BIN="${PREFIX}/bin/gfortran"
GFORTRAN_REAL="${PREFIX}/bin/gfortran.bin"
if [ -f "$XGCC_WRAPPER_SRC" ] && [ -f "$GFORTRAN_REAL" ]; then
    # Check if the current gfortran wrapper uses argv[0] (fails when invoked
    # without a full path) by looking for "argv[0]" or "strrchr" patterns
    if strings "$GFORTRAN_BIN" 2>/dev/null | grep -q "xgcc-wrap.c"; then
        # Check if it references /proc/self/exe (new version) or not (old version)
        if ! strings "$GFORTRAN_BIN" 2>/dev/null | grep -q "/proc/self/exe"; then
            "${CLANG}" -O2 -g0 -o "${GFORTRAN_BIN}" "${XGCC_WRAPPER_SRC}"
            chmod 755 "${GFORTRAN_BIN}"
            echo "  [setup] Replaced gfortran wrapper with self-relocating version"
        fi
    fi
fi

echo "gfortran environment ready"
echo "  PATH=${PREFIX}/bin"
echo "  LD_LIBRARY_PATH=${PREFIX}/lib64"
