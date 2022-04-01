#!/bin/bash

# Usage:
#     $0 <abs_path>,<ref_prefix<[<py_ver>=<rel_prefix>] ...
#     $0 ./<rel_path>,<ref_prefix<[<py_ver>=<rel_prefix>] ...
#     $0 <url>/./<dir>,<ref_prefix>[<py_ver>=<rel_prefix>|...] ...

set -e

if [ ! "$ROOT_DIR" ]; then
    printf '\033[33m[WARNING] $ROOT_DIR is not defined.\033[0m\n' >&2
    printf '\033[36m[INFO] Running in standalone mode.\033[0m\n' >&2
    export ROOT_DIR="$(realpath -e "$(dirname "$0")")"
    until [ -x "$ROOT_DIR/setup.sh" ] && [ -d "$ROOT_DIR/pkgs" ]; do export ROOT_DIR=$(realpath -e "$ROOT_DIR/.."); done
    [ "_$ROOT_DIR" != "_$(readlink -f "$ROOT_DIR/..")" ]
    printf '\033[36m[INFO] Set $ROOT_DIR to "%s".\033[0m\n' "$ROOT_DIR" >&2
    . <(sed 's/^\(..*\)/export DISTRO_\1/' '/etc/os-release')
fi

[ "$PY_VER" ] || PY_VER='^3\.'

. "$ROOT_DIR/geo/pip-mirror.sh"

CACHE_VALID=false

# Setuptools 59.7 requires Python 3.7
# Pip 22 requires Python 3.7.
for i in 'pypa/setuptools,v[3.6=v59.6.]' 'pypa/pip,[3.6=21.]' pypa/wheel PythonCharmers/python-future,v $@; do
    PKG_PATH="$(cut -d, -f1 <<< "$i" | sed 's/\/\.\/.*//')"
    PKG_SUBDIR="$(cut -d, -f1 <<< "$i" | sed -n 's/.*\/\.\/\(.*\)/\1/p')"
    ALT_PREFIX="$(cut -d, -f2 <<< "$i," | sed -n 's/.*\[\([^]\[]*\)\].*/\1/p' | tr '|' '\n')"
    if grep '^[[:alnum:]]' <<< "$PKG_PATH" > /dev/null; then
        . "$ROOT_DIR/pkgs/utils/git/version.sh" "$PKG_PATH,$(cut -d, -f2 <<< "$i," | sed 's/\[[^]\[]*\]//g')"
        URL="git+$GIT_REPO@$GIT_TAG"
    else
        URL="$(realpath -e "$PKG_PATH")"
        [ -d "$URL" ]
        USE_LOCAL_GIT=true
    fi

    PKG="$(basename "$PKG_PATH")"
    for rename in python-future=future; do
        if ! grep '^[^=][^=]*=[^=][^=]*$' <<< "$rename" >/dev/null; then
            printf '\033[31m[ERROR] Invalid pip renaming rule "%s".\033[0m\n' "$rename"
        fi
        PKG="$(sed "s/^$(cut -d'=' -f1 <<< "$rename" | sed 's/\([\\\/\.\-]\)/\\\1/g')"'$/'"$(cut -d'=' -f2 <<< "$rename" | sed 's/\([\\\/\.\-]\)/\\\1/g')/" <<< "$PKG")"
    done

    for py in {,rh-python38},python3; do
    (
        py="$py,"

        case "$DISTRO_ID" in
        'centos' | 'fedora' | 'rhel' | 'scientific')
            set +e
            . scl_source enable $(cut -d',' -f1 <<< "$py") || exit 1
            set -e
            ;;
        'debian' | 'linuxmint' | 'ubuntu')
            # Skip SCL Python.
            [ "$(cut -d',' -f1 <<< "$py")" ] && exit 0
            ;;
        *)
            printf '\033[31m[ERROR] Unknown DISTRO_ID "%s".\033[0m\n' "$DISTRO_ID" >&2
            exit 1
            ;;
        esac

        py="$(which "$(cut -d',' -f2 <<< "$py")")"
        pyver="$("$py" --version | sed 's/[[:space:]][[:space:]]*/ /g' | cut -d' ' -f2 | grep '^[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' | cut -d'.' -f-3)"
        if ! grep $(sed 's/,/\n/' <<< "$PY_VER" | sed 's/^\(..*\)/\-e \1/') <<< "$pyver" >/dev/null; then
            printf '\033[36m[INFO] Python version %s filtered by "%s".\033[0m\n' "$pyver" "$PY_VER"
            continue
        fi
        # Not exactly correct since the actual package name is defined by "setup.py".
        until $CACHE_VALID; do
            CACHED_JSON="$("$py" -m pip list --exclude-editable --format json | tr '[:upper:]' '[:lower:]')"
            CACHE_VALID=true

            # Always remove enum34.
            if jq -er '.[] | select(."name" == "enum34")' <<< "$CACHED_JSON" >/dev/null; then
                /usr/bin/sudo "$py" -m pip uninstall -y 'enum34'
                CACHE_VALID=false
                continue
            fi
        done

        grep "$(cut -d'.' -f-2 <<< "$pyver" | sed 's/\(.*\)/\^\1=/')" <<< "$ALT_PREFIX" | head -n1 | cut -d'=' -f2
        alt="$(grep "$(cut -d'.' -f-2 <<< "$pyver" | sed 's/\(.*\)/\^\1=/')" <<< "$ALT_PREFIX" | head -n1 | cut -d'=' -f2)"
        if [ "$alt" ]; then
            printf '\033[36m[INFO] %s %s may not be available for Python %s. Search for "%s" instead.\033[0m\n' "$PKG" "$GIT_TAG" "$pyver" "$alt" >&2
            . "$ROOT_DIR/pkgs/utils/git/version.sh" "$PKG_PATH,$alt"
            printf '\033[36m[INFO] Found tag "%s" instead.\033[0m\n' "$GIT_TAG" >&2
            URL="git+$GIT_REPO@$GIT_TAG"
        fi

        if [ ! "$USE_LOCAL_GIT" ] && [ "$GIT_TAG_VER" ] && [ "_$(jq -er '.[] | select(."name" == "'"$(tr '[:upper:]' '[:lower:]' <<< "$PKG")"'").version' <<< "$CACHED_JSON")" = "_$GIT_TAG_VER" ]; then
            printf '\033[36m[INFO] Package "%s" for "%s" is already up-to-date (%s). Skip.\033[0m\n' "$PKG" "$py" "$GIT_TAG_VER" >&2
            continue
        fi

        # Blacklist for wheels we cannot build yet.
        if grep -i -e"/setuptools" <<< "/$i" > /dev/null; then
            printf '\033[33m[WARNING] Cannot build "%s" from source. Install it from wheel instead.\033[0m\n' "$PKG" >&2
            URL="$PKG==$GIT_TAG_VER"
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
            URL="$(realpath -e "$PIP_CLONE_TMPDIR/$(basename "$GIT_REPO" | sed 's/\.git$//')/$PKG_SUBDIR")"
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
        elif ! grep '^[[:alnum:]]' <<< "$URL" > /dev/null; then
            sudo chown -R "$(stat -c '%u:%g' "$URL")" "$URL"
        fi
        [ ! "$SCRATCH_TMPDIR"   ] || rm -rf "$SCRATCH_TMPDIR"

        CACHE_VALID=false
    )
    done
done
