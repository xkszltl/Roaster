#!/bin/bash

for cmd in bc httping parallel; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

LINK_QUALITY="$(set -e
    parallel $(sed -n 's/\(..*\)/\-\-halt now,success=\1/p' <<< "$TOPK") -j0 'bash -c '"'"'
        set -e
        httping -Zfc10 -t3 {} 2>&1                                                                  \
        | sed -n "s/.*[^0-9]\([0-9][0-9]*\) *ok.*time  *\([0-9][0-9]*\) *ms.*/\1\/(\2\+1)\*10^3/p"  \
        | bc -l                                                                                     \
        | xargs -rn1 printf "%.3f\n"                                                                \
        | sed "s/\$/ $(sed "s/\([\\\/\.\-]\)/\\\\\1/g" <<< {})/"                                    \
        | grep .
    '"'" ::: "$@"   \
    2> /dev/null    \
    | sort -nr      \
)"
