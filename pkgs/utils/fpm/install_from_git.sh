#!/bin/bash

# ================================================================
# Package and Install from A Built Git Repo
# ================================================================

set -xe

. "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

fpm                                                             \
    --after-install "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"  \
    --after-remove "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"   \
    --chdir "$INSTALL_ROOT"                                     \
    --exclude-file "$INSTALL_ROOT/../exclude.conf"              \
    --input-type dir                                            \
    --iteration "$(git log -n1 --format="%h")"                  \
    --name "codingcafe-$(basename $(pwd))"                      \
    --output-type rpm                                           \
    --package "$INSTALL_ROOT/.."                                \
    --rpm-compression xz                                        \
    --rpm-digest sha512                                         \
    --vendor "CodingCafe"                                       \
    --version "$(git describe --tags | sed 's/[^0-9\.]//g')"

"$ROOT_DIR/pkgs/utils/fpm/install.sh"
