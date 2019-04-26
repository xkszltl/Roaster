#!/bin/bash

export CCACHE_BASEDIR="$(pwd)"
export CCACHE_COMPRESS=true
export CCACHE_MAXSIZE=64G
export CCACHE_NOHASHDIR=true

export TOOLCHAIN="$(readlink -f "$INSTALL_ROOT/../toolchain")"
mkdir -p "$TOOLCHAIN"

for i in c{c,++} g{cc,++}{,-{3,4,5,6,7,8,9}} clang{,++}{,-{3,4,5,6,7,8,9}} nvcc ld{,.lld}; do
    which $i 2> /dev/null || continue
    if which ccache > /dev/null 2> /dev/null; then
        ln -sf "$(which ccache)" "$TOOLCHAIN/$i"
    else
        ln -sf "$(which $i)" "$TOOLCHAIN/$i"
    fi
done

export TOOLCHAIN_CPU_NATIVE="$([ "_$GIT_MIRROR" == "_$GIT_MIRROR_CODINGCAFE" ] && echo 'true' || echo 'false')"

