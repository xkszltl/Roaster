# ================================================================
# Compile x264 codec
# ================================================================

[ -e $STAGE/x264 ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" videolan/x264,stable
    until git clone --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd x264

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export PKG_CONFIG_PATH="/usr/local/lib64/pkgconfig:/usr/local/lib/pkgconfig:/usr/local/lib32/pkgconfig:$PKG_CONFIG_PATH"
        export CC="ccache $CC" CXX="ccache $CXX"
        export C{,XX}FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        # Known issues:
        # - CentOS 7 only has nasm 2.10, while x264 wants 2.13.
        #   Disable until we have NASM build.
        ./configure                 \
            --disable-asm           \
            --enable-lto            \
            --enable-shared         \
            --enable-static         \
            --prefix="$INSTALL_ABS" \

        time make -j"$(nproc)"
        time make -j           install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    cd
    rm -rf $SCRATCH/x264
)
sudo rm -vf $STAGE/x264
sync || true
