#!/bin/bash

set -e

if [ ! "$ROOT_DIR" ]; then
    echo '$ROOT_DIR is not defined.'
    echo 'Running in standalone mode.'
    export ROOT_DIR="$(realpath -e "$(dirname "$0")")"
    until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(realpath -e "$ROOT_DIR/.."); done
    [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
    echo 'Set $ROOT_DIR to "'"$ROOT_DIR"'".'
fi

. "$ROOT_DIR/geo/pip-mirror.sh"

for i in setuptools pip wheel $@; do
    for py in $(which python3); do
        opt_bsp="$("$py" -m pip install --help | sed -n 's/.*\(\-\-break\-system\-packages\).*/\1/p')"
        for opt in '' '-I' ';'; do
            [ "_$opt" != '_;' ]
            ! /usr/bin/sudo -E                      \
                PATH="$PATH"                        \
                PIP_INDEX_URL="$PIP_INDEX_URL"      \
                PKG_CONFIG_PATH="$PKG_CONFIG_PATH"  \
                "$py" -m pip install                \
                --no-clean -Uv $opt $opt_bsp        \
                "$i"                                \
            || break
        done
    done
done
