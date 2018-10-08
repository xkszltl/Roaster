# ================================================================
# Compile Snappy
# ================================================================

[ -e $STAGE/snappy ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/git/version.sh" google/snappy,
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done
    cd snappy

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        # TODO: Enable test once the gtest linking issue is fixed (already in PR)
        cmake                                       \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER=gcc                  \
            -DCMAKE_CXX_COMPILER=g++                \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DSNAPPY_BUILD_TESTS=OFF                \
            -G"Ninja"                               \
            ..

        time cmake --build .
        # time cmake --build . --target test
        time cmake --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/snappy
)
sudo rm -vf $STAGE/snappy
sync || true
