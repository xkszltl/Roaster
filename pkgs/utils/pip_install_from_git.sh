#!/bin/bash

set -ex

for i in pypa/{setuptools,pip,wheel}, $@; do
    REPO="$(cut -d, -f1 <<< "$i")"
    TAG="$(cut -d, -f2 <<< "$i")"
    URL="git+$GIT_MIRROR/$REPO.git@$(git ls-remote --tags "$GIT_MIRROR/$REPO.git" | sed -n 's/.*[[:space:]]refs\/tags\/\('"$TAG"'[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)"
    [ "_$REPO" = '_pypa/setuptools' ] && URL=setuptools
    for py in python{,3}; do
        sudo "$py" -m pip install -U "$URL" || sudo "$py" -m pip install -U --ignore-installed "$URL"
    done
done
