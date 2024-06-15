#!/bin/bash

# ================================================================
# Replace shared libs with OS ABI tag newer than host kernel.
# This can help skip overly restrictive checks, e.g.:
# - Debian 11 and Ubuntu 22.04 has Qt 5.15.
# - Qt 5.12 requires renameat2() and others from kernel 3.15+.
# - CentOS 7 is on kernel 3.10.
# - ELRepo has newer kernel but may not work will with CUDA DKMS.
#
# Program will still crash if new ABI is called.
# This is technically UB and can even be insecure.
# ================================================================

set -e

cd "$(dirname "$0")"

export IS_CONTAINER="$("$ROOT_DIR/inside_container.sh" && echo 'true' || echo 'false')"
if [ ! "$IS_CONTAINER" ] || ! "$IS_CONTAINER"; then
    printf '\033[31m[ERROR] Patching OS ABI tag is very intrusive and should only be done in container.\033[0m\n' >&2
    exit 1
fi

ldconfig -p                                                                                         \
| sed -n 's/.*([^)]*OS[[:space:]][[:space:]]*ABI[[:space:]]*:[[:space:]]*\([^,]*\)[^)]*).*/\1/p'    \
| sort -V                                                                                           \
| uniq -c

ldconfig -p                                 \
| sed -n 's/.*([^)]*OS[[:space:]][[:space:]]*ABI[[:space:]]*:[[:space:]]*[Ll][Ii][Nn][Uu][Xx][[:space:]]*\([^,[:space:]]*\)[^)]*).*=>[[:space:]]*\(..*\)/\1\v\2/p'  \
| cat - <(set -e
        uname -r                            \
        | tr '[:space:]' '-'                \
        | xargs -I{} printf '%s.1\v####SPLITLINE####\n' {}
    )                                       \
| sort -V                                   \
| paste -sd"$(printf '\v')" -               \
| sed 's/.*####SPLITLINE####[[:space:]]*//' \
| tr '\v' '\n'                              \
| paste -d"$(printf '\v')" - -              \
| cut -d"$(printf '\v')" -f2                \
| xargs -rI{} realpath -e {}                \
| sort -Vu                                  \
| xargs -rI{} bash -c ':
        set -e

        lib={}
        patch="$(mktemp -t alter-os-abi-XXXXXXXX.so)"

        objcopy                                                 \
            --update-section .note.ABI-tag=<(set -e
                    readelf --hex-dump .note.ABI-tag "$lib"     \
                    | sed -n "s/^0x[^[:space:]]*[[:space:]]//p" \
                    | sed "s/[[:space:]][^[:space:]]*$//"       \
                    | xargs -n1                                 \
                    | head -n-3                                 \
                    | cat - <(set -e
                            uname -r                            \
                            | cut -d- -f1                       \
                            | cut -d. -f-3                      \
                            | tr . " "                          \
                            | xargs printf "%02x000000\n"
                        )                                       \
                    | grep .                                    \
                    | paste -sd" " -                            \
                    | xxd -p -r                                 \
                )                                               \
            "$lib"                                              \
            "$patch"

        cat "$patch"        \
        | sudo tee "$lib"   \
        > /dev/null
        rm -f "$patch"

        sudo ldconfig
    '

ldconfig -p                                                                                         \
| sed -n 's/.*([^)]*OS[[:space:]][[:space:]]*ABI[[:space:]]*:[[:space:]]*\([^,]*\)[^)]*).*/\1/p'    \
| sort -V                                                                                           \
| uniq -c
