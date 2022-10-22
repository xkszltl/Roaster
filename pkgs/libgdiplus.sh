# ================================================================
# Compile Mono's GDI+
# ================================================================

[ -e $STAGE/libgdiplus ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" mono/libgdiplus,
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd libgdiplus

    . "$ROOT_DIR/pkgs/utils/git/submodule.sh"

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export CC="ccache $CC" CXX="ccache $CXX"

        # Known issue:
        # - gtest 1.10 failed to compile on gcc-11.
        #   https://github.com/mono/libgdiplus/issues/737
        export C{,XX}FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g -Wno-maybe-uninitialized"

        # For libpng.
        export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"

        ./autogen.sh                \
            --prefix="$INSTALL_ABS" \
            --with-pango

        time make -j"$(nproc)"
        time make -j"$(nproc)" check
        time make -j           install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/libgdiplus
)
sudo rm -vf $STAGE/libgdiplus
sync || true
