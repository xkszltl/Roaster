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

CACHE_VALID=false

for i in pypa/setuptools,v pypa/{pip,wheel} $@; do
    PKG_PATH="$(cut -d, -f1 <<< "$i,")"
    if grep '^[[:alnum:]]' <<< "$PKG_PATH" > /dev/null; then
        if grep '/enum34' <<< "/$i" > /dev/null; then
            echo "Cannot get $PKG because it uses hg. Install it from wheel instead."
            URL="$PKG"
        else
            . "$ROOT_DIR/pkgs/utils/git/version.sh" "$i"
            URL="git+$GIT_REPO@$GIT_TAG"
        fi
    else
        URL="$(readlink -e $PKG_PATH)"
        [ -d "$URL" ]
        USE_LOCAL_GIT=true
    fi
    PKG="$(basename "$PKG_PATH")"
    if grep '/setuptools' <<< "/$i" > /dev/null; then
        echo "Cannot build $PKG from source. Install it from wheel instead."
        URL="$PKG"
    fi
    if grep '/protobuf' <<< "/$i" > /dev/null; then
        echo "Cannot build $PKG from source. Install it from wheel instead."
        URL="$PKG"
    fi
    for py in $(which python{,3}); do
        # Not exactly correct since the actual package name is defined by "setup.py".
        "$CACHE_VALID" || CACHED_LIST="$("$py" -m pip freeze --all | tr '[:upper:]' '[:lower:]')"
        CACHE_VALID=true
        if [ ! "$USE_LOCAL_GIT" ] && [ "_$(sed -n "s/^$(tr '[:upper:]' '[:lower:]' <<< "$PKG")==//p" <<< "$CACHED_LIST")" = "_$GIT_TAG_VER" ]; then
            echo "Package \"$PKG\" for \"$py\" is already up-to-date ($GIT_TAG_VER). Skip."
            continue
        fi
        sudo "$py" -m pip install -U "$URL" || sudo "$py" -m pip install -IU "$URL"
        CACHE_VALID=false
    done
done
