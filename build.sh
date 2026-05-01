#!/bin/sh
# Build gfortran for HarmonyOS
set -e

export TMPDIR=/storage/Users/currentUser/gfortran-harmonyos/tmp
export CONFIG_SHELL=/data/service/hnp/bin/bash
export SHELL=/data/service/hnp/bin/bash
umask 022

BUILD_DIR=/storage/Users/currentUser/gfortran-harmonyos/build

mkdir -p "$TMPDIR"
cd "$BUILD_DIR"

echo "Building gfortran..."
echo ""

make -j$(nproc) "$@"
