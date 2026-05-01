#!/bin/sh
# Configure GCC to build gfortran with OHOS Clang
set -e

# hmdfs requires group +x for directory access, even for owner
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

# OHOS Clang paths
OHOS_CLANG=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang
OHOS_CLANGXX=/data/service/hnp/bin/aarch64-unknown-linux-ohos-clang++

echo "Configuring GCC for aarch64-unknown-linux-ohos..."
echo "  Build:    $BUILD_DIR"
echo "  Install:  $PREFIX"
echo "  Compiler: $OHOS_CLANG"
echo ""

# Configure and run config.status in one pass
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
    CXXFLAGS="-O2 -g0" 2>&1

echo ""
echo "Configure done. Next: cd build && make -j\$(nproc)"
