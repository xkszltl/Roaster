#!/bin/bash

set -e

cd "$(dirname "$0")"

for cmd in find grep rsync sed sudo xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
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

ctx="$(mktemp -d "/tmp/$(basename "$0")-ctx-XXXXXXXX")"
trap "trap - SIGTERM; $(sed 's/^\(..*\)$/rm \-rf "\1"/' <<< "$ctx"); kill -- -'$$'" SIGINT SIGTERM EXIT

# Generate file list to rsync:
# - Filter out docker files.
# - Filter out tmp/system files.
# - Filter out docker networking files.
# - Sort for consistency across calls/layers.
sudo find "$src/" -mindepth 1 -maxdepth 1                                                       \
| grep -v "^$src_grep_esc/\."                                                                   \
| grep -v -e"^$src_grep_esc/"{dev,proc,sys}'$'                                                  \
| grep -v -e"^$src_grep_esc/"{media,mnt,run,tmp}'$'                                             \
| grep -v -e"^$src_grep_esc/etc/"{hosts,'resolv\.conf'}'$'                                      \
| $(which parallel >/dev/null 2>&1 && echo "parallel -j$(nproc) -kmq" || echo 'xargs -rI{}')    \
    find {} -not -type d                                                                        \
| sort -u                                                                                       \
> "$ctx/all_files.txt"

# Reshape list to matrix and take a columns for incremental rsync.
printf '\033[36m[INFO] Enlist filesystem to rebase.\033[0m\n' >&2
cat "$ctx/all_files.txt"                            \
| paste -d'\v' $(seq "$n_layers" | sed 's/..*/-/')  \
| cut -d"$(printf '\v')" -f"$layer"                 \
| grep '.'                                          \
> "$ctx/delta_files.txt"

# List multi-linked inodes to sync.
mkdir -p "$ctx/inode"
cat "$ctx/delta_files.txt"  \
| wc -l                     \
| xargs printf '\033[36m[INFO] Extract %d inode ID.\033[0m\n' >&2

pushd "$ctx/inode" >/dev/null
cat "$ctx/delta_files.txt"                                                                  \
| $(which parallel >/dev/null 2>&1 && echo "parallel -j$(nproc) -mq" || echo 'xargs -rI{}') \
    stat -c '%h %i' {}                                                                      \
| grep -v '^[01] '                                                                          \
| cut -d' ' -f2                                                                             \
| $(which parallel >/dev/null 2>&1 && echo "parallel -j$(nproc) -mq" || echo 'xargs -rI{}') \
    touch {}
popd >/dev/null

# Docker storage driver may not support hard links across layers.
# Reverse look up for multi-linked paths of inodes in list.
touch "$ctx/closure_files.txt"
if [ "$(find "$ctx/inode" -type f | wc -l)" -gt 0 ]; then
    printf '\033[36m[INFO] Create closure for %d potential inode(s).\033[0m\n' "$(find "$ctx/inode" -type f | wc -l)" >&2
    cat "$ctx/all_files.txt"                                                                    \
    | $(which parallel >/dev/null 2>&1 && echo "parallel -j$(nproc) -mq" || echo 'xargs -rI{}') \
        stat -c "[ '%h' -le 1 ] || [ ! -f '$ctx/inode/%i' ] || printf '%%s\\n' '%n'" {}         \
    | cat <(printf 'set -e\n') -                                                                \
    | bash                                                                                      \
    | sort -u                                                                                   \
    > "$ctx/closure_files.txt"
fi
rm -rf "$ctx/inode"

# Change abs path in src dir to rel path.
wc -l "$ctx/"{delta,closure}"_files.txt"    \
| head -n2                                  \
| sed 's/^[[:space:]]*//'                   \
| sed 's/[[:space:]].*//'                   \
| paste -s -                                \
| xargs -L1 printf '\033[36m[INFO] Sync %d file(s) for layer delta with %s extra(s) in inode closure.\033[0m\n'
cat "$ctx/"{delta,closure}"_files.txt"                                                      \
| sed -n 's/^'"$src_sed_esc"'\//\//p'                                                       \
| grep '.'                                                                                  \
| grep -v -e"^/etc/"{hosts,'resolv\.conf'}'$'                                               \
| sudo rsync                                                                                \
    --acls                                                                                  \
    --archive                                                                               \
    --files-from -                                                                          \
    --hard-links                                                                            \
    --info progress2                                                                        \
    --preallocate                                                                           \
    --sparse                                                                                \
    --xattrs                                                                                \
    "$src/"                                                                                 \
    "$dst/"

rm -rf "$ctx"
trap - SIGINT SIGTERM EXIT

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
