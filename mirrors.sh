#!/bin/bash

set -e

trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

cd "$(dirname "$0")"

date

# export HTTP_PROXY=proxy.codingcafe.org:8118
[ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
[ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
[ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

export ROOT=/var/mirrors
mkdir -p "$ROOT"

[ $# -ge 1 ] && export PATTERN="$1"

log="$(mktemp -t git-mirror-XXXXXXXX.log)"
! grep '[[:space:]]' <<< "$log" >/dev/null
trap "trap - SIGTERM && rm -f $log && kill -- -$$" SIGINT SIGTERM EXIT

# Concurrency restricted by GitHub.
./mirror-list.sh | parallel --bar --group --shuf -d '\n' -j 10 'bash -c '"'"'
set -e
export ARGS={}"  "
[ "$(xargs -n1 <<< {} | wc -l)" -ne 3 ] && exit 0
cd "'"$ROOT"'"
export SRC_SITE="$(cut -d" " -f1 <<< "$ARGS")"
export SRC_DIR="$(cut -d" " -f3 <<< "$ARGS")"
export SRC="$SRC_SITE$SRC_DIR.git"
export DST_DOMAIN="$(cut -d" " -f2 <<< "$ARGS" | sed "s/^\/*//" | sed "s/\/*$//" | sed "s/\(..*\)/\1\//")"
export DST_SITE="git@git.codingcafe.org:Mirrors/$DST_DOMAIN"
export DST_DIR="$SRC_DIR"
export DST="$DST_SITE$DST_DIR.git"
export LOCAL="$(pwd)/$DST_DOMAIN/$DST_DIR.git"

grep -v "^__" <<< "$SRC_DIR" >/dev/null || exit 0

if [ ! "'"$PATTERN"'" ] || grep "'"$PATTERN"'" >/dev/null <<< "$SRC_DIR"; then
    printf "\033[36m[INFO] Mirror to \"$DST_DIR\"\033[0m\n" >&2
    xargs printf "\033[36m[INFO]     %s\033[0m\n" >&2 <<< "$ARGS"

    mkdir -p "$(dirname "$LOCAL")"
    cd "$(dirname "$LOCAL")"
    set +e
    ! which scl 2>&1 > /dev/null || . scl_source enable rh-git227 || . scl_source enable rh-git218
    set -e
    [ -d "$LOCAL" ] || git clone --mirror "$DST" "$LOCAL" 2>&1 || git clone --mirror "$SRC" "$LOCAL" 2>&1
    cd "$LOCAL"
    git remote set-url origin "$DST" 2>&1
    git config remote.origin.mirror true
    git fetch origin 2>&1 || true
    git fetch --tags origin 2>&1 || true
    if git lfs ls-files | head -n1 | grep . >/dev/null || git lfs ls-files --deleted | head -n1 | grep . >/dev/null || git lfs ls-files -a | head -n1 | grep . >/dev/null; then
        git lfs fetch --all origin 2>&1 || true
    fi
    git remote set-url origin "$SRC" 2>&1
    # git fetch --prune origin 2>&1
    git fetch --prune --tags origin 2>&1
    git gc --auto 2>&1
    if git lfs ls-files | head -n1 | grep . >/dev/null || git lfs ls-files --deleted | head -n1 | grep . >/dev/null || git lfs ls-files -a | head -n1 | grep . >/dev/null; then
        git lfs fetch --all origin 2>&1 || true
        git remote set-url origin "$DST" 2>&1
        git lfs push --all origin 2>&1 || true
    fi
    git remote set-url origin "$DST" 2>&1
    git config remote.origin.mirror false
    git config --replace-all remote.origin.push "+refs/heads/*"
    git config --add         remote.origin.push "+refs/tags/*"
    git push -f         origin 2>&1
    git push -f --prune origin 2>&1
    git config --add         remote.origin.push "+refs/changes/*"
    # git config --add         remote.origin.push "+refs/keep-around/*"
    # git config --add         remote.origin.push "+refs/merge-requests/*"
    git config --add         remote.origin.push "+refs/meta/*"
    git config --add         remote.origin.push "+refs/pull/*"
    if ! git push -f origin 2>&1 && ! git --no-pager show-ref | cut -d' ' -f2- | grep "^refs/pull/" | sort -V | xargs -rn1 git push -f origin 2>&1; then
        printf "\033[31m[ERROR] Unable to push all PR refs to \"%s\".\033[0m\n" "$DST" >&2
    fi
    if ! git push -f --prune origin 2>&1; then
        printf "\033[31m[ERROR] Unable to prune PR refs on \"%s\".\033[0m\n" "$DST" >&2
    fi
    git config remote.origin.mirror true
    # git push --mirror origin 2>&1
    # git push -f --all  --prune origin 2>&1
    # git push -f --tags --prune origin 2>&1
fi
'"'" 2>&1 | tee "$log"

grep                                                                                            \
    -e 'Connection reset by'                                                                    \
    -e 'bytes of body are still expected'                                                       \
    -e 'client_loop: send disconnect'                                                           \
    -e 'error: RPC failed; curl 56 GnuTLS recv error (-9)'                                      \
    -e 'fatal: expected flush after ref listing'                                                \
    -e 'gnutls_handshake() failed: The TLS connection was non-properly terminated.'             \
    -e 'kex_exchange_identification: Connection closed by remote host'                          \
    -e 'unexpected disconnect while reading sideband packet'                                    \
    -i                                                                                          \
    "$log"                                                                                      \
| wc -l                                                                                         \
| grep -v '^0$'                                                                                 \
| xargs -r printf '\033[31m[ERROR] Found %d potential network failures in log.\033[0m\n' >&2

grep                                                                                            \
    -e 'error: update_ref failed for ref'                                                       \
    -i                                                                                          \
    "$log"                                                                                      \
| wc -l                                                                                         \
| grep -v '^0$'                                                                                 \
| xargs -r printf '\033[31m[ERROR] Found %d potential non-network failures in log.\033[0m\n' >&2

paste -sd' ' "$log"                                                                                             \
| sed 's/remote: GitLab: The default branch of a project cannot be deleted\. *To *\([^ ]*\)/\n########\1\n/g'   \
| sed -n 's/^########//p'                                                                                       \
| sed 's/^\(git\.codingcafe\.org\):/https:\/\/\1\//'                                                            \
| sed 's/\.git$/\/\-\/settings\/repository/'                                                                    \
| xargs -r printf '\033[31m[ERROR] Potential branch renaming at: %s\033[0m\n' >&2

rm -f "$log"
trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

date

trap - SIGTERM SIGINT EXIT
