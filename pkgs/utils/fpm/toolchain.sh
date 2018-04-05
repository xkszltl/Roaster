#!/bin/bash

export TOOLCHAIN="$INSTALL_ROOT/../toolchain"
mkdir -p "$TOOLCHAIN"

for i in c{c,++} g{cc,++} clang{,++} ld{,.lld}; do
    which $i 2> /dev/null || continue
    if which ccache > /dev/null 2> /dev/null; then
        ln -sf "$(which ccache)" "$TOOLCHAIN/$i"
    else
        ln -sf "$(which $i)" "$TOOLCHAIN/$i"
    fi
done

