#!/bin/bash

set -e

if [ ! "$ROOT_DIR" ]; then
    echo '$ROOT_DIR is not defined.'
    echo 'Running in standalone mode.'
    export ROOT_DIR="$(readlink -e "$(dirname "$0")")"
    until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(readlink -e "$ROOT_DIR/.."); done
    [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
    echo 'Set $ROOT_DIR to "'"$ROOT_DIR"'".'
fi

for i in pypa/{setuptools,pip,wheel} $@; do
    . "$ROOT_DIR/pkgs/utils/git/version.sh" "$i"
    URL="git+$GIT_REPO@$GIT_TAG"
    [ "_$i" = '_pypa/setuptools' ] && URL=setuptools
    for py in python{,3}; do
        sudo "$py" -m pip install -U "$URL" || sudo "$py" -m pip install -U --ignore-installed "$URL"
    done
done
