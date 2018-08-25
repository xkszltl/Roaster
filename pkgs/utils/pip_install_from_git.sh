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

for i in pypa/setuptools,v pypa/{pip,wheel} $@; do
    . "$ROOT_DIR/pkgs/utils/git/version.sh" "$i"
    URL="git+$GIT_REPO@$GIT_TAG"
    if grep 'pypa/setuptools' <<< "$i" > /dev/null; then
        echo "Cannot build setuptools from source. Install it from wheel instead."
        URL=setuptools
    fi
    for py in python{,3}; do
        sudo "$py" -m pip install -U "$URL" || sudo "$py" -m pip install -U --ignore-installed "$URL"
    done
done
