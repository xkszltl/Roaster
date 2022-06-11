#!/bin/bash

set -e

cd "$(dirname "$0")"

for cmd in find grep rsync sed sudo xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd"
    exit 1
done

[ "$src"      ] || src='/mnt/slice-src'
[ "$dst"      ] || dst='/mnt/slice-dst'
[ "$layer"    ] || layer='1'
[ "$n_layers" ] || n_layers='1'

src="$(sed 's/\/\/*/\//g' <<< "$src" | sed 's/\(.\)\/$/\1/')"
dst="$(sed 's/\/\/*/\//g' <<< "$dst" | sed 's/\(.\)\/$/\1/')"
src_grep_esc="$(sed 's/\([\.\^]\)/\\\1/g' <<< "$src")"
src_sed_esc="$(sed 's/\([\\\/\.\^\-]\)/\\\1/g' <<< "$src")"

if [ ! -d "$src/" ]; then
    printf '\033[31m[ERROR] Slicing source "%s" not found.\033[0m\n' "$src" >&2
    exit 1
fi

sudo find "$src/" -mindepth 1 -maxdepth 1           \
| grep -v "^$src_grep_esc/\."                       \
| grep -v -e"^$src_grep_esc/"{dev,proc,sys}'$'      \
| grep -v -e"^$src_grep_esc/"{media,mnt,run,tmp}'$' \
| sort                                              \
| xargs -rI{} find {} -not -type d                  \
| sort -u                                           \
| paste -d'\v' $(seq "$n_layers" | sed 's/..*/-/')  \
| cut -d"$(printf '\v')" -f"-$layer"                \
| tr '\v' '\n'                                      \
| sed -n 's/^'"$src_sed_esc"'\//\//p'               \
| grep .                                            \
| grep -v -e"^/etc/"{hosts,'resolv\.conf'}'$'       \
| sudo rsync                                        \
    --acls                                          \
    --archive                                       \
    --files-from -                                  \
    --hard-links                                    \
    --info progress2                                \
    --preallocate                                   \
    --sparse                                        \
    --xattrs                                        \
    "$src/"                                         \
    "$dst/"

if [ "$layer" -ge "$n_layers" ]; then
    printf '\033[32m[INFO] Caping on layer %d.\033[0m\n' "$layer" >&2
    sudo rsync                                                  \
        --acls                                                  \
        --archive                                               \
        --delete                                                \
        --hard-links                                            \
        --info progress2                                        \
        --inplace                                               \
        --preallocate                                           \
        --xattrs                                                \
        $(sudo find "$src/" -mindepth 1 -maxdepth 1             \
            | grep -v "^$src_grep_esc/\."                       \
            | grep -v -e"^$src_grep_esc/"{dev,proc,sys}'$'      \
            | grep -v -e"^$src_grep_esc/"{media,mnt,run,tmp}'$' \
            | grep -v -e"^$src_grep_esc/"etc'$'                 \
            | sort)                                             \
        "$dst/"
    sudo rsync                          \
        --acls                          \
        --archive                       \
        --delete                        \
        --exclude={hosts,resolv.conf}   \
        --hard-links                    \
        --info progress2                \
        --inplace                       \
        --preallocate                   \
        --xattrs                        \
        "$src/etc/"                     \
        "$dst/etc"
fi

printf '\033[32m[INFO] Sliced layer(s) %d/%d.\033[0m\n' "$layer" "$n_layers" >&2

truncate -s0 ~/.bash_history
