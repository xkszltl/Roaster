# ================================================================
# Compile Eigen
# ================================================================

[ -e $STAGE/eigen ] && ( set -xe
    cd $SCRATCH

    GIT_MIRROR='https://gitlab.com' . "$ROOT_DIR/pkgs/utils/git/version.sh" libeigen/eigen,
    until git clone --depth 1 --single-branch -b "$GIT_TAG" "$GIT_REPO" eigen; do echo 'Retrying'; done
    cd eigen

    # ------------------------------------------------------------

    . "$ROOT_DIR/pkgs/utils/fpm/pre_build.sh"

    (
        . "$ROOT_DIR/pkgs/utils/fpm/toolchain.sh"
        . "$ROOT_DIR/pkgs/utils/fpm/distro_cc.sh"

        mkdir -p build
        cd $_

        "$TOOLCHAIN/cmake"                          \
            -DCMAKE_BUILD_TYPE=Release              \
            -DCMAKE_C_COMPILER="$CC"                \
            -DCMAKE_CXX_COMPILER="$CXX"             \
            -DCMAKE_C{,XX}_COMPILER_LAUNCHER=ccache \
            -DCMAKE_C{,XX}_FLAGS="-fdebug-prefix-map='$SCRATCH'='$INSTALL_PREFIX/src' -g"   \
            -DCMAKE_INSTALL_PREFIX="$INSTALL_ABS"   \
            -DEIGEN_TEST_CUDA=ON                    \
            -DEIGEN_TEST_CXX11=ON                   \
            -DOpenGL_GL_PREFERENCE=GLVND            \
            -G"Ninja"                               \
            ..

        time "$TOOLCHAIN/cmake" --build . --target blas
        # Check may take hours.
        # time "$TOOLCHAIN/cmake" --build . --target check
        time "$TOOLCHAIN/cmake" --build . --target install
    )

    "$ROOT_DIR/pkgs/utils/fpm/install_from_git.sh"

    # ------------------------------------------------------------

    cd
    rm -rf $SCRATCH/eigen
)
sudo rm -vf $STAGE/eigen
sync || true
