#!/bin/sh

set -e

for cmd in parallel rsync; do
    ! command -v "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

seq 0 9                                         \
| parallel --lb -j10 -q sh -c 'set -ex
    for i in $(seq 5); do
        ! rsync --exclude "**/*[^{}].*" "$@"    \
        || break
    done
' -- "$@"

rsync "$@"
rsync -c "$@"
