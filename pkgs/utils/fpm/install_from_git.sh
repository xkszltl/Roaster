#!/bin/bash

# ================================================================
# Package and Install from A Built Git Repo
# ================================================================

set -xe

. "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

sudo -v

DESC="$(git describe --long --tags || echo 0.0-0-0000000)"

time fpm                                                                    \
    --after-install "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"              \
    --after-remove "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"               \
    --chdir "$INSTALL_ROOT"                                                 \
    --exclude-file "$INSTALL_ROOT/../exclude.conf"                          \
    --input-type dir                                                        \
    --iteration "$(sed 's/.*\-\([0-9]*\)\-[[:alnum:]]*$/\1/' <<< "$DESC")"  \
    --name "codingcafe-$(basename $(pwd) | tr '[:upper:]' '[:lower:]')"     \
    --output-type rpm                                                       \
    --package "$INSTALL_ROOT/.."                                            \
    --rpm-compression "$(false && echo xzmt || echo none)"                  \
    --rpm-digest sha512                                                     \
    --rpm-dist "g$(git rev-parse --short --verify HEAD)"                    \
    --vendor "CodingCafe"                                                   \
    --version "$(sed 's/\-[0-9]*\-[[:alnum:]]*$//' <<< "$DESC" | sed 's/[_\-]/\./g' | sed 's/[^0-9\.]//g' | sed 's/^[^0-9]*\(.*[0-9]\)[^0-9]*$/\1/')"

"$ROOT_DIR/pkgs/utils/fpm/install.sh"
