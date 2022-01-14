#!/bin/bash

# ================================================================
# Package and Install from A Built Git Repo
# ================================================================

set -xe

. "$ROOT_DIR/pkgs/utils/fpm/post_build.sh"

[ "$DESC" ] || DESC="$(git describe --long --match '*[0-9]*[_.-]*[0-9]' --tags || echo 0.0-0-0000000)"

for i in {"$ROOT_DIR/pkgs/utils","$INSTALL_ROOT/.."}'/fpm/post_install.sh'; do
    [ -f "$i" ] || continue
    seq 80 | sed 's/.*/#/' | paste -s - | sed 's/[[:space:]]//g'
    echo
    cat "$i"
    echo
done > "$INSTALL_ROOT/../fpm/post_install_gen.sh"

case "$DISTRO_ID" in
"centos" | "fedora" | "rhel")
    export PKG_TYPE=rpm
    ;;
"debian" | "ubuntu")
    export PKG_TYPE=deb
    ;;
*)
    export PKG_TYPE=sh
    ;;
esac

time fpm                                                                                    \
    --after-install "$INSTALL_ROOT/../fpm/post_install_gen.sh"                              \
    --after-remove "$INSTALL_ROOT/../fpm/post_install_gen.sh"                               \
    --chdir "$INSTALL_ROOT"                                                                 \
    --exclude-file "$INSTALL_ROOT/../fpm/exclude.conf"                                      \
    --input-type dir                                                                        \
    --iteration "$(sed 's/.*\-\([0-9]*\)\-[[:alnum:]]*$/\1/' <<< "$DESC")"                  \
    --name "roaster-$(basename $(pwd) | tr '[:upper:]' '[:lower:]')"                        \
    --output-type "$PKG_TYPE"                                                               \
    --package "$INSTALL_ROOT/.."                                                            \
    $(xargs -n1 <<< "$FPM_ARG_PROVIDES" | sed 's/^\(..*\)/\-\-provides \1/')                \
    --deb-compression gz                                                                    \
    --rpm-autoprov                                                                          \
    --rpm-compression "$(false && echo xzmt || echo none)"                                  \
    --rpm-digest sha512                                                                     \
    --rpm-dist "$(git rev-parse --short --verify HEAD 2>/dev/null | sed 's/^\(.\)/g\1/')"   \
    --vendor "CodingCafe"                                                                   \
    --version "$(sed 's/\-[0-9]*\-[[:alnum:]]*$//' <<< "$DESC" | sed 's/[_\-]/\./g' | sed 's/[^0-9\.]//g' | sed 's/^[^0-9]*\(.*[0-9]\)[^0-9]*$/\1/')"

"$ROOT_DIR/pkgs/utils/fpm/install.sh"
