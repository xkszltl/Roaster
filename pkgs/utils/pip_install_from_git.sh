#!/bin/bash

set -e

if [ ! "$ROOT_DIR" ]; then
    echo '$ROOT_DIR is not defined.'
    echo 'Running in standalone mode.'
    export ROOT_DIR="$(readlink -e "$(dirname "$0")")"
    until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(readlink -e "$ROOT_DIR/.."); done
    [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
    echo 'Set $ROOT_DIR to "'"$ROOT_DIR"'".'
    . <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')
fi

CACHE_VALID=false

# Known issues:
#   - Pin to setuptools v49.6.0 due to Cython LTO issue.
#     https://github.com/pypa/setuptools/issues/2374
for i in pypa/setuptools,v49 pypa/{pip,wheel} PythonCharmers/python-future,v $@; do
    PKG_PATH="$(cut -d, -f1 <<< "$i,")"
    if grep '^[[:alnum:]]' <<< "$PKG_PATH" > /dev/null; then
        . "$ROOT_DIR/pkgs/utils/git/version.sh" "$i"
        URL="git+$GIT_REPO@$GIT_TAG"
    else
        URL="$(readlink -e $PKG_PATH)"
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
            . scl_source enable $(cut -d',' -f1 <<< "$py")
            set -e
            ;;
        'ubuntu')
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

        (
            set -e
            case "$DISTRO_ID" in
            'centos' | 'fedora' | 'rhel')
                set +e
                . scl_source enable devtoolset-8
                set -e
                export CC="$(which gcc)" CXX="$(which g++)"
                ;;
            'ubuntu')
                export CC="$(which gcc-8)" CXX="$(which g++-8)"
                ;;
            *)
                echo "Unknown DISTRO_ID \"$DISTRO_ID\"."
                exit 1
                ;;
            esac
            /usr/bin/sudo -E PATH="$PATH" "$py" -m pip install -Uv "$URL" || /usr/bin/sudo -E PATH="$PATH" "$py" -m pip install -IUv "$URL"
        )

        CACHE_VALID=false
    )
    done
done
