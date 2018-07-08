# ================================================================
# Compile Snappy
# ================================================================

[ -e $STAGE/snappy ] && ( set -xe
    cd $SCRATCH
    
    # ------------------------------------------------------------

    until git clone --depth 1 --single-branch -b "$(git ls-remote --tags "$GIT_MIRROR/google/snappy.git" | sed -n 's/.*[[:space:]]refs\/tags\/\([0-9\.]*\)/\1/p' | sort -V | tail -n1)" "$GIT_MIRROR/google/snappy.git"; do echo 'Retrying'; done
    cd snappy

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        mkdir -p build
        cd $_

        # TODO: Enable test once the gtest linking issue is fixed (already in PR)
        cmake                                       \
            -DBUILD_SHARED_LIBS=ON                  \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-g"               \
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
