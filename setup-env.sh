#!/bin/sh
# Setup environment for gfortran on HarmonyOS
# Source this file: . ./setup-env.sh

PREFIX="${HOME}/.local/gfortran"

export PATH="${PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${PREFIX}/lib64:${PREFIX}/lib/gcc/aarch64-unknown-linux-ohos/14.2.0:${LD_LIBRARY_PATH}"

echo "gfortran environment ready"
echo "  PATH=${PREFIX}/bin"
echo "  LD_LIBRARY_PATH=${PREFIX}/lib64"
