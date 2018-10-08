# ================================================================
# Compile Catch2
# ================================================================

[ -e $STAGE/catch2 ] && ( set -xe
    cd $SCRATCH

    . "$ROOT_DIR/pkgs/utils/git/version.sh" catchorg/Catch2,v
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO"; do echo 'Retrying'; done

    cd Catch2

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        set +xe
        . scl_source enable devtoolset-7
        set -xe

        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"

        mkdir -p build
        cd $_

        # TODO: Currently "ApprovalTests" failed with Ninja.
        cmake                                       \
            -DCATCH_BUILD_EXAMPLES=ON               \
            -DCATCH_BUILD_EXTRA_TESTS=ON            \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER=gcc                  \
            -DCMAKE_CXX_COMPILER=g++                \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -G"Unix Makefiles"                      \
            ..

        time cmake --build . -- -j"$(nproc)"
        time cmake --build . --target test || true
        time cmake --build . --target install -- -j
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/Catch2
)
sudo rm -vf $STAGE/catch2
sync || true
