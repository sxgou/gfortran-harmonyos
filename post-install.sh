#!/bin/sh
# gfortran-harmonyos 安装后修复脚本
#
# GCC 的 make install 会将 f951 和 cc1 等二进制安装到
# ${prefix}/lib/gcc/aarch64-unknown-linux-ohos/14.2.0/ 目录,
# 但有以下问题需要在安装后修复:
#
#   1. f951 包装器硬编码了构建路径 → 替换为自定位包装器
#   2. cc1/cc1plus 包装器同样硬编码了构建路径 → 替换为自定位包装器
#   3. gfortran (xgcc) 驱动包装器硬编码了 argv[0] 路径 → 替换为自定位包装器
#   4. aarch64-unknown-linux-ohos-as 不存在 → 创建软链接
#
# 用法:  bash post-install.sh [PREFIX]
#       默认 PREFIX=$HOME/.local/gfortran
#
# 应该在 make install 之后立即运行:
#   make install prefix=$HOME/.local/gfortran
#   bash post-install.sh $HOME/.local/gfortran
#
set -e

PREFIX="${1:-${HOME}/.local/gfortran}"
GCC_LIB="${PREFIX}/lib/gcc/aarch64-unknown-linux-ohos/14.2.0"
GFORTRAN_BIN="${PREFIX}/bin"
CLANG="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang"
CLANGXX="/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++"

echo "=== gfortran-harmonyos post-install ==="
echo "  PREFIX: ${PREFIX}"
echo "  GCC lib: ${GCC_LIB}"
echo ""

# --------------------------------------------------
# 1. Replace f951 wrapper with self-relocating version
# --------------------------------------------------
echo "[1/4] Replacing f951 wrapper ..."
WRAPPER_SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/wrappers/f951-wrap.c"
if [ -f "$WRAPPER_SRC" ]; then
    "${CLANG}" -O2 -g0 -o "${GCC_LIB}/f951" "${WRAPPER_SRC}"
    chmod 755 "${GCC_LIB}/f951"
    echo "  [OK] f951 wrapper compiled and installed"
else
    echo "  [SKIP] ${WRAPPER_SRC} not found"
fi
echo ""

# --------------------------------------------------
# 2. Replace cc1/cc1plus wrappers if they exist
# --------------------------------------------------
echo "[2/4] Replacing cc1/cc1plus wrappers ..."
CC1_WRAPPER_SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/wrappers/cc1-wrap.c"
INSTALLED_CC1="${GCC_LIB}/cc1"
if [ -f "$CC1_WRAPPER_SRC" ] && [ -f "$INSTALLED_CC1" ]; then
    "${CLANG}" -O2 -g0 -o "${GCC_LIB}/cc1" "${CC1_WRAPPER_SRC}"
    chmod 755 "${GCC_LIB}/cc1"
    echo "  [OK] cc1 wrapper compiled and installed"
else
    echo "  [SKIP] cc1 not installed (Fortran-only build), skipping cc1 wrapper"
fi

# cc1plus — install as symlink to cc1 wrapper if cc1plus.real exists
INSTALLED_CC1PLUS="${GCC_LIB}/cc1plus"
if [ -f "$CC1_WRAPPER_SRC" ] && [ -f "$INSTALLED_CC1PLUS" ]; then
    "${CLANG}" -O2 -g0 -o "${GCC_LIB}/cc1plus" "${CC1_WRAPPER_SRC}"
    chmod 755 "${GCC_LIB}/cc1plus"
    echo "  [OK] cc1plus wrapper compiled and installed"
else
    echo "  [SKIP] cc1plus not installed, skipping"
fi
echo ""

# --------------------------------------------------
# 3. Replace gfortran/xgcc driver wrapper with self-relocating version
# --------------------------------------------------
echo "[3/4] Replacing gfortran driver wrapper ..."
GCC_WRAPPER_SRC="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)/wrappers/xgcc-wrap.c"
GFORTRAN_BIN_DIR="${PREFIX}/bin"
if [ -f "$GCC_WRAPPER_SRC" ] && [ -f "${GFORTRAN_BIN_DIR}/gfortran.bin" ]; then
    "${CLANG}" -O2 -g0 -o "${GFORTRAN_BIN_DIR}/gfortran" "${GCC_WRAPPER_SRC}"
    chmod 755 "${GFORTRAN_BIN_DIR}/gfortran"
    echo "  [OK] gfortran wrapper compiled and installed"
else
    echo "  [SKIP] gfortran.bin not found, skipping xgcc-wrap"
fi
echo ""

# --------------------------------------------------
# 4. Create aarch64-unknown-linux-ohos-as symlink
# --------------------------------------------------
echo "[4/4] Creating aarch64-unknown-linux-ohos-as symlink ..."
AS_TARGET="${GFORTRAN_BIN}/aarch64-unknown-linux-ohos-as"
if command -v as >/dev/null 2>&1; then
    AS_SOURCE="$(command -v as)"
    ln -sf "${AS_SOURCE}" "${AS_TARGET}"
    echo "  [OK] ${AS_TARGET} → ${AS_SOURCE}"
else
    echo "  [WARN] as not found in PATH, trying /data/service/hnp/bin/as"
    if [ -x /data/service/hnp/bin/as ]; then
        ln -sf /data/service/hnp/bin/as "${AS_TARGET}"
        echo "  [OK] ${AS_TARGET} → /data/service/hnp/bin/as"
    else
        echo "  [FAIL] as not found anywhere. Create manually:"
        echo "    ln -sf /path/to/as ${AS_TARGET}"
        exit 1
    fi
fi
echo ""

echo "=== Done ==="
echo "Run 'source ${PREFIX}/../setup-env.sh' to set up the environment."
