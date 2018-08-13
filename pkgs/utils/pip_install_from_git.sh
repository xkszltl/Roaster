#!/bin/bash

set -ex

sudo pip3 install -U setuptools

for i in pypa/pip, $@; do
    REPO="$(cut -d, -f1 <<< "$i")"
    TAG="$(cut -d, -f2 <<< "$i")"
    sudo pip3 install -U "git+$GIT_MIRROR/$REPO.git@$(git ls-remote --tags "$GIT_MIRROR/$REPO.git" | sed -n 's/.*[[:space:]]refs\/tags\/\('"$TAG"'[0-9\.]*\)[[:space:]]*$/\1/p' | sort -V | tail -n1)"
done
