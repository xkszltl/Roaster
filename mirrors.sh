#!/bin/bash

set -e

cd "$(dirname "$0")"

date

# export HTTP_PROXY=proxy.codingcafe.org:8118
[ $HTTP_PROXY ] && export HTTPS_PROXY=$HTTP_PROXY
[ $HTTP_PROXY ] && export http_proxy=$HTTP_PROXY
[ $HTTPS_PROXY ] && export https_proxy=$HTTPS_PROXY

export ROOT=/var/mirrors
mkdir -p "$ROOT"

[ $# -ge 1 ] && export PATTERN="$1"

# Concurrency restricted by GitHub.
./mirror-list.sh | parallel --bar --group --shuf -d '\n' -j 10 'bash -c '"'"'
set -e
export ARGS={}"  "
xargs -n1 <<< "$ARGS"
[ $(xargs -n1 <<< {} | wc -l) -ne 3 ] && exit 0
cd "'"$ROOT"'"
export SRC_SITE="$(cut -d" " -f1 <<< "$ARGS")"
export SRC_DIR="$(cut -d" " -f3 <<< "$ARGS")"
export SRC="$SRC_SITE$SRC_DIR.git"
export DST_DOMAIN="$(cut -d" " -f2 <<< "$ARGS" | sed "s/^\/*//" | sed "s/\/*$//" | sed "s/\(..*\)/\1\//")"
export DST_SITE="git@git.codingcafe.org:Mirrors/$DST_DOMAIN"
export DST_DIR="$SRC_DIR"
export DST="$DST_SITE$DST_DIR.git"
export LOCAL="$(pwd)/$DST_DOMAIN/$DST_DIR.git"

echo "[\"$DST_DIR\"]"

grep -v "^__" <<< "$SRC_DIR" || exit 0

if [ ! "'"$PATTERN"'" ] || grep "'"$PATTERN"'" <<< "$SRC_DIR"; then
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
    [ "$(git lfs ls-files -a)" ] && git lfs fetch --all origin 2>&1 || true
    git remote set-url origin "$SRC" 2>&1
    # git fetch --prune origin 2>&1
    git fetch --prune --tags origin 2>&1
    git gc --auto 2>&1
    [ "$(git lfs ls-files -a)" ] && git lfs fetch --all origin 2>&1 || true
    git remote set-url origin "$DST" 2>&1
    [ "$(git lfs ls-files -a)" ] && git lfs push --all origin 2>&1 || true
    git config --replace-all remote.origin.push "+refs/heads/*"
    git config --add         remote.origin.push "+refs/tags/*"
    git config remote.origin.mirror false
    # git push --mirror origin 2>&1
    # git push -f --all  --prune origin 2>&1
    # git push -f --tags --prune origin 2>&1
    git push -f         origin 2>&1
    git push -f --prune origin 2>&1
    git config remote.origin.mirror true
fi
'"'"

date
