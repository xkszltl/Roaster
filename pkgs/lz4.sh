# ================================================================
# Compile LZ4
# ================================================================

[ -e $STAGE/lz4 ] && ( set -xe
    cd $SCRATCH

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" lz4/lz4,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd lz4

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        export CC="$(which ccache) $CC" CXX="$(which ccache) $CXX"
        export CFLAGS="$CFLAGS -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"
        export CXXFLAGS="$CXXFLAGS -O3 -fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"

        # Explicitly inject $CFLAGS due to https://github.com/lz4/lz4/issues/958
        make all CFLAGS="$CFLAGS" -j$(nproc)
        # Parallel test does not work: https://github.com/lz4/lz4/issues/957
        make check
        # Only run quick tests (check) by default.
        # make test
        make PREFIX="$INSTALL_ABS" install -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/lz4
)
sudo rm -vf $STAGE/lz4
sync || true
