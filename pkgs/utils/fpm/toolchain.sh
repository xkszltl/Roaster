#!/bin/bash

export CCACHE_BASEDIR="$(pwd)"
export CCACHE_COMPRESS=true
export CCACHE_NOHASHDIR=true

export TOOLCHAIN="$(readlink -f "$INSTALL_ROOT/../toolchain")"
mkdir -p "$TOOLCHAIN"

for cmd in c{c,++} g{cc,++}{,-{3,4,5,6,7,8,9}} clang{,++}{,-{3,4,5,6,7,8,9}} nvcc ld{,.lld}; do
    which "$cmd" 2> /dev/null || continue
    if which ccache > /dev/null 2> /dev/null; then
        ln -sf "$(which ccache)" "$TOOLCHAIN/$cmd"
    else
        ln -sf "$(which "$cmd")" "$TOOLCHAIN/$cmd"
    fi
done

export TOOLCHAIN_CPU_NATIVE="$([ "_$GIT_MIRROR" = "_$GIT_MIRROR_CODINGCAFE" ] && echo 'true' || echo 'false')"

for cmd in cmake ctest; do
    whereis -b "$cmd"{,2,3}                     \
    | sed 's/^[^[:space:]]*:[[:space:]]*//'     \
    | xargs -rn1                                \
    | sort -u                                   \
    | xargs -rI{} find {} -maxdepth 0 -type f   \
    | xargs -rI{} bash -c '
        set -e
        {} --version                            \
        | sed -n "s/^[[:space:]]*'"$cmd"'[^[:space:]]* version[[:space:]][[:space:]]*\([0-9\.]*\)[[:space:]]*$/\1/p"    \
        | head -n1                              \
        | xargs printf "%s\t%s\n" {}
    '                                           \
    | cut -f1                                   \
    | tail -n1                                  \
    | xargs -rI{} ln -sfT {} "$TOOLCHAIN/$cmd"
done

ls -la "$TOOLCHAIN"
