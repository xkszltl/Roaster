#!/bin/bash

set -e

for cmd in find grep sed xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

# Be extremely cautious with this dangerous script. 

if [ "_$(uname -s)" != '_Linux' ]; then
    printf '\033[31m[ERROR] Unexpected OS "%s".\033[0m\n' "$(uname -s)" >&2
    exit 1
fi

if ! (grep '^[^:]*:[^:]*:/.' /proc/1/cgroup >/dev/null || [ -e /.dockerenv ] || [ -e /run/.containerenv ]); then
    printf '\033[31m[ERROR] Only run within container or it will damage the system.\033[0m\n' >&2
    exit 1
fi

# Do not dedup empty/tiny files, as they are more likely to be false positives.
[ "$min_size" ] || min_size=4096

chksum_dir="$(mktemp -dt 'inode-dedup-XXXXXXXX')"
trap "trap - SIGTERM; $(sed 's/^\(..*\)$/rm \-rf "\1"/' <<< "$chksum_dir"); kill -- -'$$'" SIGINT SIGTERM EXIT

# Hash metadata+data, permissively, and report inexact matches as suggestions.
# Record as symlink if never seen, or hard link to target of the symlink.
cat "$@"                                            \
| xargs -rI{} find {} -type f                       \
| xargs -rI{} bash -c "$(printf '%s' '
        set -e;
        src='"'"'{}'"'"';
        chksum_dir='"'$chksum_dir'"';
        min_size='"'$min_size'"';
        if [ "$(stat -c "%s" "$src")" -ge "$min_size" ]; then
            printf '"'"'%s/%s\v%s\n'"'"'
                "$chksum_dir"
                "$(stat -c "%D" "$src"
                    | cat - "$src"
                    | sha512sum
                    | cut -d" " -f1
                )"
                "$src";
        fi;
    '                                               \
    | sed 's/^[[:space:]]*//'                       \
    | grep '.'                                      \
    | paste -sd' ' -
)"                                                  \
| grep '.'                                          \
| sed -n 's/\(.*\)'"$(printf '\v')"'\(.*\)/'"$(
    printf '%s' '
        chksum='"'"'\1'"'"';
        src='"'"'\2'"'"';
        if [ -e "$chksum" ]; then
            if [ "_$(stat -Lc "%D %u:%g %04a" "$chksum")" != "_$(stat -Lc "%D %u:%g %04a" "$src")" ]; then
                printf '"'"'\033[33m[WARNING] Dedup of "%s" skipped due to mismatched permission.\033[0m\n'"'"' "$src";
                stat "$(realpath -e "$chksum")" "$src"
                | sed "s/^/$(printf "\033[33m[WARNING]     ")/"
                | sed "s/\$/$(printf "\033[0m")/";
            elif [ "_$(stat -Lc "%i" "$chksum")" != "_$(stat -Lc "%i" "$src")" ]; then
                printf '"'"'\033[36m[INFO] Dedup file "%s" -> "%s".\033[0m\n'"'"' "$src" "$(realpath -e "$chksum")";
                ln -Lfn "$chksum" "$src";
            fi;
        else
            ln -fns "$src" "$chksum";
        fi;
    '                                               \
    | sed 's/\([]\[\\\/\&\|\^\$\.\-]\)/\\\1/g'      \
    | sed 's/\\\(\\[1-9]\)/\1/g'                    \
    | sed 's/^[[:space:]]*//'                       \
    | grep '.'                                      \
    | paste -sd' ' -
)"'/p'                                              \
| cat <(printf 'set -e\n') -                        \
| bash

rm -rf "$chksum_dir"
trap - SIGTERM SIGINT EXIT

printf '\033[32m[INFO] File dedup completed.\033[0m\n' >&2
