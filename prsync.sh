#!/bin/sh

set -e

for cmd in parallel rsync xargs; do
    ! command -v "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

date
seq 100                                                                                 \
| parallel --lb -j20 -q sh -c 'set -ex
    tid={}
    for i in $(seq 5); do
        ! find "$'$(expr "$#" - 1 || true)'/././././" -not -type d                      \
        | sed "s/.*\\/\\.\\/\\.\\/\\.\\/\\.\\//**\\//"                                  \
        | paste -d "$(printf "\v")" '"$(seq 100 | sed 's/..*/\-/' | paste -sd' ' -)"'   \
        | cut -d "$(printf "\v")" -f "$tid"                                             \
        | rsync --include-from - --include "**/" --exclude "*" "$@"                     \
        || break
        sleep "0.$tid"
    done
' -- "$@"

date
rsync "$@"

printf '\033[36m[INFO] Verify remote content.\033[0m\n' >&2
date
rsync -c "$@"
date
printf '\033[32m[INFO] Rsync completed.\033[0m\n' >&2
