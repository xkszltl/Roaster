#!/bin/bash

# ================================================================
# Package and Install from A Built Git Repo
# ================================================================

set -xe

. "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

sudo -v

time fpm                                                                \
    --after-install "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"          \
    --after-remove "$ROOT_DIR/pkgs/utils/fpm/post_install.sh"           \
    --chdir "$INSTALL_ROOT"                                             \
    --exclude-file "$INSTALL_ROOT/../exclude.conf"                      \
    --input-type dir                                                    \
    --iteration "$(git log -n1 --format="%h")"                          \
    --name "codingcafe-$(basename $(pwd) | tr '[:upper:]' '[:lower:]')" \
    --output-type rpm                                                   \
    --package "$INSTALL_ROOT/.."                                        \
    --rpm-compression "$(false && echo xzmt || echo none)"              \
    --rpm-digest sha512                                                 \
    --vendor "CodingCafe"                                               \
    --version "$((git describe --tags || echo 0.0) | sed 's/[_\-]/\./g' | sed 's/[^0-9\.]//g' | sed 's/^[^0-9]*//')"

"$ROOT_DIR/pkgs/utils/fpm/install.sh"
