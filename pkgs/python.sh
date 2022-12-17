# ================================================================
# Compile Python
# ================================================================

for i in python-3.{,1,2,3,4,5,6,7,8,9}{0,1,2,3,4,5,6,7,8,9}; do
    [ -e "$STAGE/$i" ] && ( set -xe
        cd "$SCRATCH"
        ver="$(printf '%s' "$i" | cut -d- -f2)"

        # ------------------------------------------------------------

        . "$ROOT_DIR/pkgs/utils/git/version.sh" "python/cpython,v$ver."
        until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO" "python-$ver"; do echo 'Retrying'; done
        cd "python-$ver"

        # ------------------------------------------------------------

        . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

        (
            . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
            . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

            export CC="$(which ccache) $CC" CXX="$(which ccache) $CXX"
            export CFLAGS="$CFLAGS -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
            export CXXFLAGS="$CXXFLAGS -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

            ./configure                 \
                --enable-optimizations  \
                --enable-shared         \
                --prefix="$INSTALL_ABS" \
                --with-lto

            time make all -j"$(nproc)"
            # Skip testing due to accessibility of www.pythontest.net and smtp.gmail.com used.
            : || time make test -j"$(nproc)"
            time make install -j
        )

        # Remove common parts without minor version.
        find -L "$INSTALL_ABS/bin/"                -type f -not -name "*$ver*"   -not -name "*$(printf '%s' "$ver" | tr -d .)*"   | xargs -rI{} rm -f {}
        find -L "$INSTALL_ABS/lib"*"/" -maxdepth 1 -type f -not -name "*$ver*"   -not -name "*$(printf '%s' "$ver" | tr -d .)*"   | xargs -rI{} rm -f {}
        find -L "$INSTALL_ABS/lib"*"/pkgconfig/"   -type f -not -name "*$ver*"   -not -name "*$(printf '%s' "$ver" | tr -d .)*"   | xargs -rI{} rm -f {}
        find -L "$INSTALL_ABS/share/man/"          -type f -not -name "*$ver*.*" -not -name "*$(printf '%s' "$ver" | tr -d .)*.*" | xargs -rI{} rm -f {}

        "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

        # ------------------------------------------------------------

        cd
        rm -rf "$SCRATCH/python-$ver"
    )
    sudo rm -vf "$STAGE/$i"
    sync || true
done
