#!/bin/bash

set -e

if [ ! "$ROOT_DIR" ]; then
    echo '$ROOT_DIR is not defined.'
    echo 'Running in standalone mode.'
    export ROOT_DIR="$(realpath -e "$(dirname "$0")")"
    until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(realpath -e "$ROOT_DIR/.."); done
    [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
    echo 'Set $ROOT_DIR to "'"$ROOT_DIR"'".'
    . <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')
fi

. "$ROOT_DIR/geo/pip-mirror.sh"

CACHE_VALID=false

for i in pypa/setuptools,v pypa/{pip,wheel} PythonCharmers/python-future,v $@; do
    PKG_PATH="$(cut -d, -f1 <<< "$i,")"
    if grep '^[[:alnum:]]' <<< "$PKG_PATH" > /dev/null; then
        . "$ROOT_DIR/pkgs/utils/git/version.sh" "$i"
        URL="git+$GIT_REPO@$GIT_TAG"
    else
        URL="$(realpath -e $PKG_PATH)"
        [ -d "$URL" ]
        USE_LOCAL_GIT=true
    fi

    PKG="$(basename "$PKG_PATH")"
    if [ "_$PKG" = "_python-future" ]; then
        PKG="future"
    fi

    for wheel_only in pillow protobuf setuptools; do
        if grep -i "/$wheel_only" <<< "/$i" > /dev/null; then
            echo "Cannot build $PKG from source. Install it from wheel instead."
            URL="$PKG"
            break
        fi
    done
    # SCL python throws FileNotFound error in PyTorch pip build,
    # Not sure why but disable for now since stock version is already 3.6.8 (SCL version 3.6.9).
    # for py in ,python3 rh-python38,python; do
    for py in ,python3; do
    (
        py="$py,"

        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel')
            set +e
            . scl_source enable $(cut -d',' -f1 <<< "$py") || exit 1
            set -e
            ;;
        'debian' | 'linuxmint' | 'ubuntu')
            # Skip SCL Python.
            [ "$(cut -d',' -f1 <<< "$py")" ] && exit 0
            ;;
        *)
            echo "Unknown DISTRO_ID \"$DISTRO_ID\"."
            exit 1
            ;;
        esac

        py="$(which "$(cut -d',' -f2 <<< "$py")")"
        # Not exactly correct since the actual package name is defined by "setup.py".
        until $CACHE_VALID; do
            CACHED_LIST="$("$py" -m pip freeze --all | tr '[:upper:]' '[:lower:]')"
            CACHE_VALID=true

            # Always remove enum34.
            if [ "$(grep '^enum34==' <<< "$CACHED_LIST")" ]; then
                /usr/bin/sudo "$py" -m pip uninstall -y 'enum34'
                CACHE_VALID=false
                continue
            fi
        done
        if [ ! "$USE_LOCAL_GIT" ] && [ "$GIT_TAG_VER" ] && [ "_$(sed -n "s/^$(tr '[:upper:]' '[:lower:]' <<< "$PKG")==//p" <<< "$CACHED_LIST")" = "_$GIT_TAG_VER" ]; then
            echo "Package \"$PKG\" for \"$py\" is already up-to-date ($GIT_TAG_VER). Skip."
            continue
        fi

        # Clone git repo using local mirror.
        if [ "_$URL" = "_git+$GIT_REPO@$GIT_TAG" ]; then
            [ "$SCRATCH" ] && [ -d "$SCRATCH" ] && SCRATCH_TMPDIR='' || SCRATCH_TMPDIR="$(mktemp -d)"
            [ ! "$SCRATCH_TMPDIR" ] || SCRATCH="$SCRATCH_TMPDIR"
            PIP_CLONE_TMPDIR="$(mktemp -d "$SCRATCH/mirrored-pip-XXXXXX")"
            (
                set -e
                cd "$PIP_CLONE_TMPDIR"
                git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"
                cd "$(basename "$GIT_REPO" | sed 's/\.git$//')"
                "$ROOT_DIR/pkgs/utils/git/submodule.sh"
            )
            URL="$(realpath -e "$PIP_CLONE_TMPDIR/$(basename "$GIT_REPO" | sed 's/\.git$//')")"
            [ "$URL" ]
            [ -d "$URL" ]
        fi

        (
            set -e

            . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"
            set +x
            for opt in '' '-I' ';'; do
                [ "_$opt" != '_;' ]
                ! /usr/bin/sudo -E PATH="$PATH" PIP_INDEX_URL="$PIP_INDEX_URL" "$py" -m pip install --no-clean $([ ! "$USE_LOCAL_GIT" ] || echo '--use-feature=in-tree-build') -Uv $opt "$URL" || break
            done
        )

        if [ "$PIP_CLONE_TMPDIR" ]; then
            (
                set -e
                pushd "$PIP_CLONE_TMPDIR/$(basename "$GIT_REPO" | sed 's/\.git$//')"
                sudo git clean -dfx
                sudo git submodule foreach --recursive git clean -dfx
            )
            rm -rf "$PIP_CLONE_TMPDIR"
        fi
        [ ! "$SCRATCH_TMPDIR"   ] || rm -rf "$SCRATCH_TMPDIR"

        CACHE_VALID=false
    )
    done
done
