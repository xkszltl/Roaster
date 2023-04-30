#!/bin/sh

set -e

for cmd in git grep sed xargs; do
    ! which "$cmd" >/dev/null || continue
    printf '\033[31m[ERROR] Missing command "%s".\033[0m\n' "$cmd" >&2
    exit 1
done

while [ "$#" -gt 0 ]; do
    case "$1" in
    '--')
        shift
        break
        ;;
    '--dst' | '-t')
        if [ "$#" -lt 2 ] || [ ! "$2" ] || printf '%s' "$2" | grep -e '^\-' -e '^\-\-$' >/dev/null; then
            printf '\033[31m[ERROR] Missing value of "%s".\033[0m\n' "$1" >&2
            exit 1
        fi
        dst="$2"
        shift 2
        ;;
    '--dst-suffix' | '-T')
        if [ "$#" -lt 2 ] || [ ! "$2" ] || printf '%s' "$2" | grep -e '^\-' -e '^\-\-$' >/dev/null; then
            printf '\033[31m[ERROR] Missing value of "%s".\033[0m\n' "$1" >&2
            exit 1
        fi
        [ ! "$dst_suffix" ] && [ "$2" ] && dst_suffix="$2" || dst_suffix="$dst_suffix:$2" || dst_suffix="$2"
        shift 2
        ;;
    '--help' | '-h')
        printf "Usage:git via [--dst <url>]... [--src <repo_pattern>]... [--dst-suffix <list>]... [--src-suffix <list>]... [--] <git_command> [args...]\n" >&2
        exit 0
        ;;
    '--src' | '-s')
        if [ "$#" -lt 2 ] || [ ! "$2" ] || printf '%s' "$2" | grep -e '^\-' -e '^\-\-$' >/dev/null; then
            printf '\033[31m[ERROR] Missing value of "%s".\033[0m\n' "$1" >&2
            exit 1
        fi
        src="$(printf '%s\n' "$src" "$2" | grep . | cat -)"
        shift 2
        ;;
    '--src-suffix' | '-S')
        if [ "$#" -lt 2 ] || [ ! "$2" ] || printf '%s' "$2" | grep -e '^\-' -e '^\-\-$' >/dev/null; then
            printf '\033[31m[ERROR] Missing value of "%s".\033[0m\n' "$1" >&2
            exit 1
        fi
        [ ! "$src_suffix" ] && [ "$2" ] && src_suffix="$2" || src_suffix="$src_suffix:$2" || src_suffix="$2"
        shift 2
        ;;
    *)
        break
        ;;
    esac
done

if [ ! "$dst" ]; then
    dst='https://git.codingcafe.org/Mirrors/'
    printf '\033[36m[INFO] Defaulted to route via "%s".\033[0m\n' "$dst" >&2
fi
if printf '%s\n' "$dst" | grep . | tail -n1 | sed 's/^.*\(.\)$/\1/' | grep '[[:alnum:]]' >/dev/null; then
    printf '\033[33m[WARNING] Destination URL usually ends with a non-alphabetic separator, e.g. \"/\" or ":".\033[0m\n'
fi

[ "$src" ] || src='[^[:space:]]*'

# Semicolon-separated list for suffix, with auto-dedup.
# Use ':' for empty.
# Set both to empty to match suffix.
[ "$src_suffix" ] || src_suffix=':.git'
[ "$dst_suffix" ] || dst_suffix='.git'

# Algorithm:
# - Canonicalize spacing to exactly 1 between fields.
# - 3-fold amplification:
#     - Protocol (HTTPS/SSH)
#     - Source/destination suffix.
# - Remove duplicated / and recover :// for protocol.
# - Interlace with a dummy line and dedup, to add a single line for 0-based count.
# - Use line number as count on each line, and re-group to keep only the greatest.
eval $(set -e +x >/dev/null
        "$(dirname "$(realpath "$0")")/../mirror-list.sh"                           \
        | sed 's/[[:space:]][[:space:]]*/ /g'                                       \
        | sed 's/^ //'                                                              \
        | sed 's/ $//'                                                              \
        | grep -e '$^' $(
                printf '%s' "$src"                                                  \
                | xargs -rn1                                                        \
                | xargs -rn1 printf ' -e%s'
            )                                                                       \
        | sed 's/^\(https:\/\/\)\([^\/][^\/]*\)\(\/\)\(.*\)/\1\2\3\4\ngit@\2:\4/'   \
        | sort -u                                                                   \
        | sed 's/^\(git@\)\([^\/][^\/]*\)\(:\)\(.*\)/\1\2\3\4\nhttps:\/\/\2\/\4/'   \
        | sort -u                                                                   \
        | sed -n 's/^\([^ ][^ ]*\) \([^ ][^ ]*\) \([^ ][^ ]*\)$/url\.'"$(
                printf '%s' "$dst"                                                  \
                | sed 's/\([\\\/\.\-]\)/\\\1/g'
            )"'\2\/\3\.insteadOf \1\2\/\3/p'                                        \
        | sed -n 's/\(..*\)/'"$(
                printf '%s\n' "$src_suffix"                                         \
                | sed 's/^/1/'                                                      \
                | sed 's/:/\n1/g'                                                   \
                | sort -u                                                           \
                | sed 's/\([\\\/\.\-]\)/\\\1/g'                                     \
                | xargs -rI{} printf '\\%s\\n' {}
            )"'/p'                                                                  \
        | grep .                                                                    \
        | sed -n 's/\(..*\)\(\.insteadOf .*\)/'"$(
                printf '%s\n' "$dst_suffix"                                         \
                | sed 's/^/1/'                                                      \
                | sed 's/:/\n1/g'                                                   \
                | sort -u                                                           \
                | sed 's/\([\\\/\.\-]\)/\\\1/g'                                     \
                | xargs -rI{} printf '\\%s\\2\\n' {}
            )"'/p'                                                                  \
        | grep .                                                                    \
        | sed 's/\/\/*/\//g'                                                        \
        | sed 's/\(https:\/\)/\1\//g'                                               \
        | sed 's/$/\n~~ ~~/'                                                        \
        | sort -u                                                                   \
        | nl -s' ' -v"$(
                printf '%s\n0\n' "$GIT_CONFIG_COUNT"                                \
                | grep .                                                            \
                | sort -n                                                           \
                | tail -n1
            )" -w10                                                                 \
        | sed 's/^[[:space:]]*//'                                                   \
        | sed -n 's/^\([^ ][^ ]*\) \([^ ][^ ]*\) \([^ ][^ ]*\)$/GIT_CONFIG_COUNT=\1\nGIT_CONFIG_KEY_\1=\2\nGIT_CONFIG_VALUE_\1=\3/p'    \
        | grep -v '^GIT_CONFIG_[A-Z][A-Z]*_[0-9][0-9]*=~~$'                         \
        | sort -V                                                                   \
        | paste -sd' ' -                                                            \
        | sed 's/.*\(GIT_CONFIG_COUNT=[1-9][0-9]*\)/\1/'                            \
        | tr ' ' '\n'
    )                                                                               \
    git "$@"
